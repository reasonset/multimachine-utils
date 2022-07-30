#!/usr/bin/ruby
require 'yaml'
require 'json'
require 'optparse'
require 'socket'

class MmFfT9Info
  def initialize opts
    @config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    load_config opts[:type]
    @mode = case 
    when opts[:yaml]
      :yaml
    when opts[:json]
      :json
    else
      :pp
    end
    @full_queue = opts[:full]
    @compact = opts[:compact]
    @squashed = opts[:squashed]
    @hr = opts[:"human-readable"]
    @now = Time.now
  end

  def load_config type
    config = YAML.load(File.read("#{@config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
    abort "No such type" unless @config
  end

  def hr total
    return total unless @hr
    case
    when total >= 1_000_000_000_000_000
      (total / 1_000_000_000_000_000).to_s + "PB"
    when total >= 1_000_000_000_000
      (total / 1_000_000_000_000).to_s + "TB"
    when total >= 1_000_000_000
      (total / 1_000_000_000).to_s + "GB"
    when total >= 1_000_000
      (total / 1_000_000).to_s + "MB"
    when total >= 1_000
      (total / 1_000).to_s + "kB"
    end
  end

  def time_format(sec)
    sprintf("%d:%02d:%02d",
            (sec / (60 * 60)),
            (sec % (60 * 60) / 60),
            (sec % 60))
  end

  def fprint_info info
    total_size = 0
    unknown_num = 0

    power_map = {}
    info[:holds].each do |k, v|
      power_map[k] = v[:power]
    end

    info[:queue].each do |i|
      if i[:size] > 1000
        total_size += i[:size]
      else
        unknown_num += 1
      end
    end

    info[:queue_size] = hr total_size
    info[:unknown_size_items] = unknown_num
    info[:queue_length] = info[:queue].length
    info[:num_of_workers] = info[:workers].length
    info[:worker_total_size] = hr info[:workers].sum {|k, v| v[:processing][:size] }

    unless @full_queue
      info[:queue] = info[:queue].first 5
    end

    if @squashed
      info[:queue] = info[:queue].map {|i| sprintf("%s @%s", i[:title], (hr(i[:size]) || "clip")) }
    elsif @compact
      info[:queue] = info[:queue].map {|i| {
        file: i[:outfile],
        title: i[:title],
        size: hr(i[:size]),
      }}
    end

    if @squashed
      info[:workers] = info[:workers].each do |k, v|
        info[:workers][k] = sprintf("%s @%s - %s / %s",
                                    v[:processing][:title],
                                    (hr(v[:processing][:size]) || "clip"),
                                    time_format(@now - v[:atime]),
                                    (time_format((v[:processing][:size]) / power_map[k.sub(/.*?@/, "")]) rescue "???"))
      end
    elsif @compact
      info[:workers] = info[:workers].each do |k, v|
        info[:workers][k] = {
          at: v[:atime].to_s,
          estimated_size: hr(v[:processing][:size]),
          source: v[:processing][:file],
          title: v[:processing][:title]
        }
      end
    end

    case @mode
    when :json
      puts JSON.pretty_generate(info)
    when :yaml
      YAML.dump(info, STDOUT)
    else
      pp info
    end
  end

  def connect
    sock = TCPSocket.open(@config["host"], @config["port"])
    Marshal.dump({cmd: :info}, sock)
    sock.close_write
    info = Marshal.load(sock)

    fprint_info(info)
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-y", "--yaml")
op.on("-j", "--json")
op.on("-f", "--full")
op.on("-c", "--compact")
op.on("-s", "--squashed")
op.on("-h", "--human-readable")

op.parse!(ARGV, into: opts)

mmff = MmFfT9Info.new(opts)
mmff.connect