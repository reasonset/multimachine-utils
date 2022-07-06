#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'

class MmFfT9
  def initialize opts
    load_config opts[:type]

    @hosts = Hash.new(0)
    @holds = []
    @state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @qf = "#{@state_dir}/reasonset/mmfft9/queue.rbm"
    @ef = "#{@state_dir}/reasonset/mmfft9/errors"
    create_queue
  end

  def load_config type
    config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    config = YAML.load(File.read("#{config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
    abort "No such type" unless @config
  end

  def create_queue
    unless File.exist? "#{@state_dir}/reasonset/mmfft9"
      abort %:No state directory found. please run mkdir -pv "#{@state_dir}/reasonset/mmfft9":
    end
    if File.exist? @qf
      @queue = Marshal.load File.read @qf
      File.delete @qf
    else
      @queue = []
    end
  end

  def add list
    @queue.concat list
    @queue.sort_by! {|i| [-(i[:priority] || 0), -i[:size]] }
    @queue.uniq!
    pp @queue
  end

  def take req
    leading = 0
    @holds.each do |x|
      leading += x[:holds] if x[:name] != req[:name]
    end

    list = @queue[leading..]
    entity = if req[:request_min]
      @queue.pop
    elsif req[:limit]
      index = @queue.index {|i| i[:size] < req[:limit]}
      if index
        @queue.delete_at index
      else
        {bye: true}
      end
    else
       @queue.shift
    end

    entity
  end

  def save_queue
    File.open @qf, "w" do |f|
      Marshal.dump @queue, f
    end
  end

  def add_host req
    name = req[:name]
    @hosts[name] += 1
    unless @holds.index name
      @holds.push({
        name: name,
        power: req[:power],
        holds: req[:holds]
      })
      @holds.sort_by! {|i| -i[:power] }
    end
  end

  def del_host req
    name = req[:name]
    @hosts[name] -= 1
    if @hosts[name] <= 0
      @hosts.delete name
      @holds.sort_by! {|i| -i[:power] }
    end
  end

  def main
    server = TCPServer.open(@config["port"])
    begin
      while sock = server.accept
        cmd = Marshal.load sock
        sock.close_read
        puts "=============> Request Accepted @ #{Time.now.to_s}"
        pp cmd

        case cmd[:cmd]
        when :add
          add cmd[:list]
        when :take
          add_host cmd if cmd[:new]
          i = take cmd
          if i
            Marshal.dump i, sock
          else
            Marshal.dump({bye: true}, sock)
            del_host cmd
          end
        when :bye
          del_host cmd
        end
        sock.close
        puts "=============> Request Closed"
        pp({hosts: @hosts, holds: @holds, queue_length: @queue.length})
      end
    ensure
      save_queue
    end
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")

op.parse!(ARGV, into: opts)

mmff = MmFfT9.new(opts)
mmff.main