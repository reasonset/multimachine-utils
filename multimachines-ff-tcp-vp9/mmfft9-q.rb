#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'
require_relative 'mmfft9-power.rb'

class MmFfT9Q
  def initialize opts
    @opts = opts
    load_config opts[:type]
  end

  def load_config type
    config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    config = YAML.load(File.read("#{config_dir}/reasonset/mmfft9.yaml"))
    @type = type&.to_s || "default"
    @config = config[@type]
    abort "No such type" unless @config

    unless @opts[:resume]
      @config["this"] = YAML.load(File.read("./.mmfft9.yaml"))
    end
  end

  def outfile_format file
    case @config["this"]["style"]&.downcase
    when "relive"
      # AMD Radeon ReLive.
      File.basename(file.chomp, ".*").sub(/^.*?_/, "") + ".webm" # title_date-time[_n].mp4
    when "coloros"
      # ColorOS mobile screen recorder.
      name = File.basename(file.strip, ".*")
      if name =~ /^Record/
        name.sub(/^Record_/, "").sub(/_.*/, "") + ".webm"
      elsif name =~ /^[-0-9]+_[a-f0-9]+$/
        name.sub(/_.*/, "") + ".webm"
      else
        name + ".webm"
      end
    when "xrecorder"
      # XRecorder screen recorder
      name = File.basename(file.strip, ".*")
      if name =~ /^XRecorder_/
        name = name.sub(/^XRecorder_/, "")
        sprintf("%d.%02d.%02d-%02d.%02d.%02d.webm", name[4, 4], name[2, 2], name[0,2], name[9, 2], name[11, 2], name[13, 2])
      elsif name =~ /(\d{2})(\d{2})(\d{4})_(\d{2})(\d{2})(\d{2})/
        sprintf("%d.%02d.%02d-%02d.%02d.%02d.webm", $3, $2, $1, $4, $5, $6)
      else
        name + ".webm"
      end
    when "obs"
      # OBS Studio.
      File.basename(file.chomp, ".*").tr(" ", "_") + ".webm"
    when "generaldt"
      # General DateTime
      name = File.basename(file.chomp, ".*")
      if name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})/
        # To Second
        "#{$1}.#{$2}.#{$3}-#{$4}.#{$5}.#{$6}.webm"
      elsif name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})[-._: ]?(\d{2})/
        # To Minute
        "#{$1}.#{$2}.#{$3}-#{$4}.#{$5}-#{$$}.webm"
      else
        # No match. use without filename conversion.
        name + ".webm"
      end
    when "origin"
      # Get file datetime
      timestamp = nil
      begin
        timestamp = File.birthtime(File.join(@config["sourcedir"], @config["this"]["prefix"], file.chomp))
      end

      timestamp.strftime("%Y.%m.%d-%H.%M.%S.webm")
    else
      # No filename conversion.
      File.basename(file.chomp, ".*") + ".webm"
    end
  end

  def create_rate
    rate = 1.0
    if @config["this"]["power_rate"]
      rate = @config["this"]["power_rate"]
    elsif @config["use_calc_rate"]
      calc = MmFfT9Pw.new({"drop-rate": @config["drop_rate"], "standard-title": @config["standard"], type: @type})
      calc.calc
      rate = calc.rate @config["this"]["title"]
    end
  
    @rate = rate
  end  

  def calc_size file
    (File::Stat.new(file.chomp).size / @rate).to_i
  end

  def load_list io
    if @opts[:resume]
      @list = YAML.load io
    else
      @list = []
      create_rate
      case @config["this"]["style"]&.downcase
      when "named"
        # Tab separated, source_path\tdest_filename
        io.each do |i|
          source_file, dest_file = *i.chomp.split("\t", 2)
          @list.push({
            file: source_file,
            outfile: (dest_file + ".webm"),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            size: calc_size(i),
            original_size: File::Stat.new(i.chomp).size,
            ff_options: @config["this"]["ff_options"] || {}
          })
        end
      when "clip"
        # Tab separated, source_path\tss\tto\tdest_filename.
        # set nil to ss or to if - is given.
        io.each do |i|
          source_file, ss, t, dest_file = *i.chomp.split("\t", 4)
          ss = nil if ss == "-"
          t = nil if t == "-"
          ff_clip = {}
          ff_clip["ss"] = ss
          ff_clip["to"] = t
          # If ss or to given, set 10 to size to be ignored. Otherwise set size.
          size = (ss or t) ? (@config["this"]["hugeclip"] ? calc_size(source_file) : 10) : calc_size(source_file)

          @list.push({
            file: source_file,
            outfile: (dest_file + ".webm"),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            original_size: File::Stat.new(source_file).size,
            size: size,
            ff_options: (@config["this"]["ff_options"] || {}).merge(ff_clip)
          })
        end
      when "rclip"
        # For rythem game best play clip.
        # Tab separated, `source_path ss to song difficulty tags`
        # set nil to ss or to if - is given.
        io.each do |i|
          source_file, ss, t, song, difficulty, tags = *i.chomp.split("\t", 6)
          ss = nil if ss == "-"
          t = nil if t == "-"
          ff_clip = {}
          ff_clip["ss"] = ss
          ff_clip["to"] = t
          # If ss or to given, set 10 to size to be ignored. Otherwise set size.
          size = (ss or t) ? 10 : calc_size(source_file)

          name = File.basename(source_file, ".*")
          date = (name =~ /(\d{4})[-._: ]?(\d{2})[-._: ]?(\d{2})/ ? "#{$1}.#{$2}.#{$3}" : "")
          outfile = [song, difficulty, date, tags].join("-")

          @list.push({
            file: source_file,
            outfile: (outfile + ".webm"),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            original_size: File::Stat.new(source_file).size,
            size: size,
            ff_options: (@config["this"]["ff_options"] || {}).merge(ff_clip)
          })
        end
      else
        io.each do |i|
          @list.push({
            file: i.chomp,
            outfile: outfile_format(i),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            size: calc_size(i),
            original_size: File::Stat.new(i.chomp).size,
            ff_options: @config["this"]["ff_options"] || {}
          })
        end
      end
    end
  end

  def connect
    sock = TCPSocket.open(@config["host"], @config["port"])
    Marshal.dump({
      cmd: :add,
      list: @list
    }, sock)
    sock.close_write
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-r", "--resume")

op.parse!(ARGV, into: opts)

mmff = MmFfT9Q.new(opts)
mmff.load_list ARGF
mmff.connect
