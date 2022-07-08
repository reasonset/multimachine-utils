#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'
require 'dbm'

class MmFfT9R
  def initialize opts
    @config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    @xdg_state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @state_dir = "#{@xdg_state_dir}/reasonset/mmfft9"
    load_config opts[:type]
    calc_power
    @limit = nil
    if opts[:limit]
      @limit = (@power / 60.0 * opts[:limit].to_i).to_i
    end
    @request_min = opts[:"request-min"]
  end

  def load_config type
    config = YAML.load(File.read("#{@config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
    abort "No such type" unless @config
  end

  def calc_power
    STDERR.puts "=========> Calculating power..."
    @power = if File.exist? "#{@state_dir}/power"
      cost_list = []
      File.open "#{@state_dir}/power" do |f|
        f.flock File::LOCK_SH
        f.each do |line|
          i = line.chomp.sub("\t.*", "")
          cost_list.push(i.to_i)
        end
        f.flock File::LOCK_EX
      end
      perc = cost_list.length / 10
      valid_list = cost_list.sort.drop(perc).reverse.drop(perc)

      if !valid_list || valid_list.empty?
        0
      else
        valid_list.sum / valid_list.length
      end
    else
      0
    end
    STDERR.puts "=========> Set power [#{@power} bytes in second]"
  end

  def ff res
    STDERR.puts "=========> Going ffmpeg #{res[:file]}"
    # Setup
    cmdlist = []
    cmdlist << "-nostdin"        # Do not use STDIN
    cmdlist << "-n"              # Do not overwrite
    cmdlist << "-ss" << res[:ff_options]["ss"] if res[:ff_options]["ss"] # SKIP
    cmdlist << "-to" << res[:ff_options]["to"] if res[:ff_options]["to"] # Time duration
    cmdlist << "-i" << "#{@config["sourcedir"]}/#{res[:source_prefix]}/#{res[:file]}"
    cmdlist << "-vf" << res[:ff_options]["vf"] if  res[:ff_options]["vf"]
    cmdlist << "-minrate" << res[:ff_options]["min"] if  res[:ff_options]["min"]
    cmdlist << "-maxrate" << res[:ff_options]["max"] if  res[:ff_options]["max"]
    cmdlist << "-tile-columns" << res[:ff_options]["tile"] if  res[:ff_options]["tile"]
    cmdlist << "-threads" << res[:ff_options]["threads"] if  res[:ff_options]["threads"]
    cmdlist << "-quality" << res[:ff_options]["quality"] if  res[:ff_options]["quality"]
    cmdlist << "-cpu-used" << res[:ff_options]["cpu"] if  res[:ff_options]["cpu"]
    cmdlist << "-c:v" << "libvpx-vp9"
    cmdlist << "-r" << res[:ff_options]["r"].to_s if res[:ff_options]["r"]
    cmdlist << "-crf" << (res[:ff_options]["crf"]&.to_s || "44")
    cmdlist << "-c:a" << "libopus"
    cmdlist << "-b:a" << (res[:ff_options]["ba"] || "128k")
    cmdlist << "-speed" << res[:ff_options]["speed"] if  res[:ff_options]["speed"]
    cmdlist << "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"

    Dir.mkdir "#{@config["outdir"]}/#{res[:title]}" unless File.exist? "#{@config["outdir"]}/#{res[:title]}"

    fail_reason = nil
    if File.exist? "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"
      fail_reason = "existing"
    else
      time_start = Time.now
      # ffmpeg
      system("ffmpeg", *cmdlist)
      status = $?
      time_end = Time.now
      if status != 0
        fail_reason = "ffmpeg_nonzero"
      end
    end

    # errors
    if fail_reason
      res["fail_status"] = fail_reason
      unless File.exist? "#{@state_dir}/errors.yaml"
        File.open("#{@state_dir}/errors.yaml", "w") {|f| YAML.dump([], f)}
      end
      File.open("#{@state_dir}/errors.yaml", "r+") do |f|
        f.flock(File::LOCK_EX)
        begin
          errors = YAML.load f
          f.seek 0
          f.truncate 0
          errors.push(res)
          YAML.dump errors, f
        ensure
          f.flock(File::LOCK_UN)
        end
      end
    else
      # write elapsed
      begin
        elapsed = (time_end - time_start).to_i
        if elapsed > 0
          save_power res, elapsed
          save_title_power res, elapsed
        end
      rescue
        nil
      end
    end
  end

  def save_power res, elapsed
    # Record power. It wants 1MiB source size at least.
    if res[:size] > (1024 * 1024)
      File.open("#{@state_dir}/power", "a") do |f|
        f.flock(File::LOCK_EX)
        begin
          f.seek(0, IO::SEEK_END)
          f.printf("%d\t%s\t%s", (res[:size] / elapsed), res[:source_prefix], res[:file])
        rescue
          STDERR.puts "Failed to save power"
        ensure
          f.flock(File::LOCK_UN)
        end
      end
    end
  end

  def save_title_power res, elapsed
    # Record title power. It wants 1MiB source size at least.
    if res[:size] > (1024 * 1024)
      DBM.open("#{@state_dir}/title_power") do |dbm|
        power_list = dbm.key?(res[:title]) ? Marshal.load(dbm[res[:title]]) : []
        power_list.push(res[:original_size] / elapsed)
        dbm[res[:title]] = Marshal.dump(power_list)
      end
    end
  end

  def connect
    first = true
    loop do
      sock = TCPSocket.open(@config["host"], @config["port"])
      # Stop request if ~/.local/state/reasonset/mmfft9/exit is exist.
      if File.exist? "#{@state_dir}/exit"
        Marsha.dump({
          cmd: :bye,
          name: @config["hostname"]
        })
        break
      else
        # Request next one.
        Marshal.dump({
          cmd: :take,
          new: first,
          worker_id: sprintf("%d@%s", Process.pid, @config["hostname"]),
          holds: @config["holds"],
          power: @power,
          name: @config["hostname"],
          request_min: @request_min,
          limit: ((!@limit || @limit.zero?) ? nil : @limit)
        }, sock)
        sock.close_write
        first &&= false
        res = Marshal.load(sock)
        sock.close
        break if res[:bye]
        ff res
      end
    end

  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-l min", "--limit")
op.on("-m", "--request-min")

op.parse!(ARGV, into: opts)

mmff = MmFfT9R.new(opts)
mmff.connect