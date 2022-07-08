#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'

class MmFfT9Q
  def initialize opts
    @opts = opts
    load_config opts[:type]
  end

  def load_config type
    config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    config = YAML.load(File.read("#{config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
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
      File.basename(path.strip, ".*").sub(/^Record_/, "") + ".webm"
    else
      # No filename conversion.
      File.basename(file.chomp, ".*") + ".webm"
    end
  end

  def calc_size file
    (File::Stat.new(file.chomp).size / (@config["this"]["power_rate"] || 1.0)).to_i
  end

  def load_list io
    if @opts[:resume]
      @list = YAML.load io
    else
      @list = []
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
          @list.push({
            file: source_file,
            outfile: (dest_file + ".webm"),
            source_prefix: @config["this"]["prefix"],
            title: @config["this"]["title"],
            size: 10,
            ff_options: (@config["this"]["ff_options"] || {}).merge(ff_clip)
          })
        end
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
            ff_options: @config["this"]["ff_options"] || {}
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