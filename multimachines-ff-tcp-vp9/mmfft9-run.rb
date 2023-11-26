#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'
require 'dbm'
require 'fileutils'
require_relative 'mmfft9-power.rb'

class MmFfT9R
  CRF_DEFAULT_VALUE = 42

  def initialize opts
    @config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    @xdg_state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @state_dir = "#{@xdg_state_dir}/reasonset/mmfft9"
    @ccwd = nil
    @cwd = Dir.pwd
    load_config opts[:type]
    calc_power
    @limit = nil
    if opts[:limit]
      @limit = (@power / 60.0 * opts[:limit].to_i).to_i
    elsif opts[:"limit-size"]
      @limit = opts[:"limit-size"].to_i * 1_000_000
    end
    @request_min = opts[:"request-min"]
    @worker_id = sprintf("%d@%s", Process.pid, @config["hostname"])
  end

  def chdir
    dirname = Time.now.strftime("%s.#{$$}")

    Dir.mkdir(File.join(@state_dir, "run")) unless File.exist? File.join(@state_dir, "run")
    Dir.mkdir File.join(@state_dir, "run", dirname)
    Dir.chdir File.join(@state_dir, "run", dirname) && @ccwd = Dir.pwd
  end

  def load_config type
    config = YAML.load(File.read("#{@config_dir}/reasonset/mmfft9.yaml"))
    @type = type&.to_s || "default" 
    @config = config[@type]
    abort "No such type" unless @config
  end

  def calc_power
    STDERR.puts "=========> Calculating power..."
    @power = if @config["presumptive_power"]
      @config["presumptive_power"]
    elsif File.exist? "#{@state_dir}/power"
      calc = MmFfT9Pw.new({"drop-rate": @config["drop_rate"], "standard-title": @config["standard"]})
      calc.calc
      calc.power
    else
      0
    end
    STDERR.puts "=========> Set power [#{@power} bytes in second]"
  end

  def interrupt res
    p "interrupt"
    # Clean up
    outfile = "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"
    File.delete outfile if File.exist? outfile

    # Send die command
    sock = TCPSocket.open(@config["host"], @config["port"])
    Marshal.dump({
      cmd: :die,
      resource: res,
      name: @config["hostname"],
      worker_id: @worker_id
    }, sock)
    sock.close
    exit 127
  end
  
  def ff1 res, crf: nil, bv: nil
    # Setup
    cmdlist = []
    cmdlist << "-nostdin"        # Do not use STDIN
    cmdlist << "-n"              # Do not overwrite
    cmdlist << "-ss" << res[:ff_options]["ss"] if res[:ff_options]["ss"] # SKIP
    cmdlist << "-to" << res[:ff_options]["to"] if res[:ff_options]["to"] # Time duration
    cmdlist << "-i" << "#{@config["sourcedir"]}/#{res[:source_prefix]}/#{res[:file]}"
    cmdlist << "-vf" << res[:ff_options]["vf"] if  res[:ff_options]["vf"]
    cmdlist << "-tile-columns" << res[:ff_options]["tile"] if  res[:ff_options]["tile"]
    cmdlist << "-threads" << res[:ff_options]["threads"] if  res[:ff_options]["threads"]
    cmdlist << "-quality" << res[:ff_options]["quality"] if  res[:ff_options]["quality"]
    cmdlist << "-cpu-used" << res[:ff_options]["cpu"] if  res[:ff_options]["cpu"]
    cmdlist << "-c:v" << "libvpx-vp9"
    cmdlist << "-b:v" << bv if bv
    cmdlist << "-minrate" << res[:ff_options]["min"] if  res[:ff_options]["min"]
    cmdlist << "-maxrate" << res[:ff_options]["max"] if  res[:ff_options]["max"]
    cmdlist << "-r" << res[:ff_options]["r"].to_s if res[:ff_options]["r"]
    cmdlist << "-crf" << crf if crf
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
      ffmpeg_inprogress = true
      begin
        # ffmpeg
        system("ffmpeg", *(cmdlist.map {|i| i.to_s}))
        ffmpeg_inprogress = false
        status = $?
        time_end = Time.now
        if status != 0
          fail_reason = "ffmpeg_nonzero"
        end
      ensure
        # Interrupt action
        interrupt res if ffmpeg_inprogress
      end
    end

    {time_start: time_start, time_end: time_end, fail_reason: fail_reason}
  rescue => e
    return {fail_reason: "Script: #{e}"}
  end

  # 2pass encoding.
  def ff2 res, crf: nil, bv: nil
    # SetupA
    cmdlist = []
    cmdlist1 = []
    cmdlist2 = []
    cmdlist << "-nostdin"        # Do not use STDIN
    cmdlist << "-n"              # Do not overwrite
    cmdlist << "-ss" << res[:ff_options]["ss"].to_s if res[:ff_options]["ss"] # SKIP
    cmdlist << "-to" << res[:ff_options]["to"].to_s if res[:ff_options]["to"] # Time duration
    cmdlist << "-i" << "#{@config["sourcedir"]}/#{res[:source_prefix]}/#{res[:file]}"
    cmdlist << "-vf" << res[:ff_options]["vf"] if  res[:ff_options]["vf"]
    cmdlist << "-tile-columns" << res[:ff_options]["tile"].to_s if  res[:ff_options]["tile"]
    cmdlist << "-threads" << res[:ff_options]["threads"].to_s if  res[:ff_options]["threads"]
    cmdlist << "-quality" << res[:ff_options]["quality"].to_s if  res[:ff_options]["quality"]
    cmdlist << "-cpu-used" << res[:ff_options]["cpu"].to_s if  res[:ff_options]["cpu"]
    cmdlist << "-speed" << res[:ff_options]["speed"].to_s if  res[:ff_options]["speed"]
    cmdlist << "-c:v" << "libvpx-vp9"
    cmdlist << "-b:v" << bv.to_s if bv
    cmdlist << "-minrate" << res[:ff_options]["min"].to_s if  res[:ff_options]["min"]
    cmdlist << "-maxrate" << res[:ff_options]["max"].to_s if  res[:ff_options]["max"]
    cmdlist << "-r" << res[:ff_options]["r"].to_s if res[:ff_options]["r"]
    cmdlist << "-crf" << crf if crf
    cmdlist1 << "-pass" << "1" 
    cmdlist2 << "-pass" << "2" 
    cmdlist1 << "-an"
    cmdlist1 << "-f" << "null"
    cmdlist1 << "/dev/null"
    cmdlist2 << "-c:a" << "libopus"
    cmdlist2 << "-b:a" << (res[:ff_options]["ba"] || "128k")
    cmdlist2 << "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"

    Dir.mkdir "#{@config["outdir"]}/#{res[:title]}" unless File.exist? "#{@config["outdir"]}/#{res[:title]}"

    fail_reason = nil
    if File.exist? "#{@config["outdir"]}/#{res[:title]}/#{res[:outfile]}"
      fail_reason = "existing"
    else
      ffmpeg_inprogress = true
      begin
        STDERR.puts "=======> PASS 1"
        system("ffmpeg", *((cmdlist + cmdlist1).map {|i| i.to_s }))
        status = $?

        if status.success?
          STDERR.puts "=======> PASS 2"
          time_start = Time.now
          # ffmpeg
          system("ffmpeg", *((cmdlist + cmdlist2).map {|i| i.to_s }))
          ffmpeg_inprogress = false
          status = $?
          time_end = Time.now
          unless status.success?
            fail_reason = "ffmpeg_nonzero_pass2"
          end
        else
          ffmpeg_inprogress = false
          fail_reason = "ffmpeg_nonzero_pass1"
        end
      ensure
        # Interrupt action
        interrupt res if ffmpeg_inprogress
      end
    end

    {time_start: time_start, time_end: time_end, fail_reason: fail_reason}
  rescue => e
    return {fail_reason: "Script: #{e}"}
  end

  def ff res
    STDERR.puts "=========> Going ffmpeg #{res[:file]}"
    # CRF value
    #   Default: CRF 42 (any of bv, minrate or maxrate is not defined.)
    crf = res[:ff_options]["crf"]
    unless crf
      if !res[:ff_options]["bv"] && !res[:ff_options]["minrate"] && !res[:ff_options]["maxrate"]
        crf = CRF_DEFAULT_VALUE
      end
    end
    bv = res[:ff_options]["bv"] || (crf ? 0 : nil)

    options = {
      crf: crf,
      bv: bv
    }
    result = res[:ff_options]["2pass"] ? ff2(res, **options) : ff1(res, **options)
    time_start = result[:time_start]
    time_end = result[:time_end]
    fail_reason = result[:fail_reason]

    # errors
    if fail_reason
      res["fail_status"] = fail_reason
      res["at"] = Time.new.to_s
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
      rescue => e
        STDERR.puts "!!! #{e} (@power)"
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
          f.printf("%d\t%s\t%s\n", (res[:size] / elapsed), res[:source_prefix], res[:file])
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
      STDERR.puts "=======> Writing title power #{res[:original_size]}/#{elapsed} for #{res[:source_prefix]}"
      DBM.open("#{@state_dir}/#{@type}-title_power") do |dbm|
        power_list = dbm.key?(res[:source_prefix]) ? Marshal.load(dbm[res[:source_prefix]]) : []
        power_list.push(res[:original_size] / elapsed)
        dbm[res[:source_prefix]] = Marshal.dump(power_list)
      end
    end
  end

  def connect
    loop do
      sock = TCPSocket.open(@config["host"], @config["port"])
      # Stop request if ~/.local/state/reasonset/mmfft9/exit is exist.
      if File.exist? "#{@state_dir}/exit"
        Marshal.dump({
          cmd: :bye,
          name: @config["hostname"],
          worker_id: @worker_id
        }, sock)
        break
      else
        # Request next one.
        Marshal.dump({
          cmd: :take,
          worker_id: @worker_id,
          holds: @config["holds"],
          power: @power,
          name: @config["hostname"],
          request_min: @request_min,
          limit: ((!@limit || @limit.zero?) ? nil : @limit)
        }, sock)
        sock.close_write
        res = Marshal.load(sock)
        sock.close
        break if res[:bye]
        ff res
      end
    end

  ensure
    Dir.chdir @cwd
    FileUtils.rm_rf @ccwd if @ccwd && File.exist? @ccwd
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-l minutes", "--limit")
op.on("-L megabyte", "--limit-size")
op.on("-m", "--request-min")

op.parse!(ARGV, into: opts)

mmff = MmFfT9R.new(opts)
mmff.chdir
mmff.connect
