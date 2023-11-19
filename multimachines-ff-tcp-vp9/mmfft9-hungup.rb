#!/usr/bin/ruby
require 'yaml'
require 'json'
require 'optparse'
require 'socket'

class MmFfT9HUP
  def initialize opts, host
    @config_dir = ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config"
    load_config opts[:type]
    @takeback = opts[:takeback]
    @host = host
  end

  def load_config type
    config = YAML.load(File.read("#{@config_dir}/reasonset/mmfft9.yaml"))
    @config = config[type&.to_s || "default"]
    abort "No such type" unless @config
  end

  def workers info
    info[:workers].keys.select {|k| File.fnmatch @host, k}
  end

  def connect
    sock = TCPSocket.open(@config["host"], @config["port"])
    Marshal.dump({cmd: :info}, sock)
    sock.close_write
    info = Marshal.load(sock)
    sock.close
    
    target = workers info
    target.each do |k|
      cmd = nil
      if @takeback
        cmd = {
          cmd: :die,
          resource: info[:workers][k][:processing],
          name: @config["hostname"],
          worker_id: k
        }
      else
        cmd = {
          cmd: :bye,
          name: @config["hostname"],
          worker_id: k
        }
      end
      pp cmd
      sock = TCPSocket.open(@config["host"], @config["port"])
      Marshal.dump(cmd, sock)
      sock.close
    end
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-b", "--takeback")

op.parse!(ARGV, into: opts)

host = ARGV.shift

unless host
  abort "No host pattern given."
end

mmff = MmFfT9HUP.new(opts, host)
mmff.connect
