#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'

class MmFfT9R
  def initialize opts
    load_config opts[:type]
    calc_power
    @limit = nil
    if opts[:limit]
      @limit = (@power / 60.0 * opts[:limit].to_i).to_i
    end
    @xdg_state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @state_dir = "#{@xdg_state_dir}/reasonset/mmfft9"
    @config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    @request_min = opts[:request_min]
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
          i = line.chomp
          cost_list.push(i.to_i)
        end
        f.flock File::LOCK_EX
      end
      perc = cost_list.length / 10
      valid_list = cost_list.sort[perc, (perc * 8)]
      if !valid_list || valid_list.empty
        0
      else
        valid_list.sum / (perc * 8)
      end
    else
      0
    end
  end

  def ff res
    STDERR.puts "=========> Going ffmpeg #{res[:file]}"
    # Setup
    cmdlist = []
    cmdlist << "-nostdin"        # Do not use STDIN
    cmdlist << "-n"              # Do not overwrite
    cmdlist << "-ss" << res[:ff_options]["ss"] if res[:ff_options]["ss"] # SKIP
    cmdlist << "-t" << res[:ff_options]["t"] if res[:ff_options]["t"] # Time duration
    cmdlist << "-i" << "#{@config["sourcedir"]}/#{res[:source_prefix]}/#{res[:file]}"
    cmdlist << "-c:v" << "libvpx-vp9"
    cmdlist << "-r" << res[:ff_options]["r"].to_s if res[:ff_options]["r"]
    cmdlist << "-crf" << (res[:ff_options]["crf"]&.to_s || "44")
    cmdlist << "-c:a" << "libopus"
    cmdlist << "-b:a" << (res[:ff_options]["ba"] || "128k")
    cmdlist << "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"

    Dir.mkdir "#{@config["outdir"]}/#{res[:title]}" unless File.exist? "#{@config["outdir"]}/#{res[:title]}"

    time_start = Time.now
    # ffmpeg
    system("ffmpeg", *cmdlist)
    status = $?
    time_end = Time.now

    # errors
    if status != 0
      unless File.exist? "#{@state_dir}/errors"
        File.open("#{@state_dir}/errors", "w") {|f| YAML.dump([], f)}
      end
      File.open("#{@state_dir}/errors", "r+") do |f|
        f.flock(File::LOCK_EX)
        begin
          errors = YAML.load f
          f.seek(0)
          f.truncate
          errors.push(res)
          YAML.dump errors, f
        ensure
          f.flock(File::LOCK_UN)
        end
      end
    end

    # write elapsed
    begin
      elapsed = (time_end - time_start).to_i
      File.open("#{@state_dir}/power", "a") do |f|
        f.flock(File::LOCK_EX)
        begin
          f.seek(0, IO::SEEK_END)
          f.puts(res[:size] / elapsed)
        ensure
          f.flock(File::LOCK_UN)
        end
      end
    rescue
      nil
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