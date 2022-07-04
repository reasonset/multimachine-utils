#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'

class MmFfT9Q
  def initialize opts
    load_config opts[:type]
  end

  def load_config type
    config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    config = YAML.load(File.read("#{config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
    abort "No such type" unless @config

    @config["this"] = YAML.load(File.read("./.mmfft9.yaml"))
  end

  def outfile_format file
    case @config["this"]["style"]&.downcase
    when "relive"
      File.basename(file.chomp, ".*").sub(/^.*?_/, "") + ".webm" # title_date-time[_n].mp4
    when "coloros"
      File.basename(path.strip, ".*").sub(/^Record_/, "") + ".webm"
    else
      File.basename(file.chomp, ".*") + ".webm"
    end
  end

  def calc_size file
    if @config["this"]["style"].downcase == "clip"
      10
    else
      (File::Stat.new(file.chomp).size / (@config["this"]["power_rate"] || 1.0)).to_i
    end
  end

  def load_list io
    @list = []
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

op.parse!(ARGV, into: opts)

mmff = MmFfT9Q.new(opts)
mmff.load_list ARGF
mmff.connect