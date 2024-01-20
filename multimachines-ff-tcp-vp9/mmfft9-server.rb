#!/usr/bin/ruby
require 'yaml'
require 'optparse'
require 'socket'

class MmFfT9
  def initialize opts
    load_config opts[:type]

    @hosts = Hash.new(0)
    @holds = {}
    @workers = {} # For log only
    @state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @verbose = opts[:verbose]
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
    @queue = @queue.sort_by {|i| [(i[:priority] || 0), i[:size]] }.uniq.reverse
    pp @queue
  end

  def take req
    puts "------------ TAKE START" if @verbose
    leading = 0
    holds = @holds.keys.sort_by {|k| @holds[k][:power] }.reverse
    pp holds if @verbose
    holds.each do |x|
      break if @holds[x][:name] == req[:name]
      leading += @holds[x][:holds]
    end
    pp leading if @verbose

    puts "------------ TAKE CHECK EMPTY" if @verbose
    list = @queue[leading..]
    if !list || list.empty?
      puts "List is empty." if @verbose
      return nil
    end

    puts "------------ TAKE PICKUP ITEM" if @verbose
    entity = if req[:request_min]
      @queue.pop
    elsif req[:limit]
      index = list.index {|i| i[:size] < req[:limit]}
      if index
        @queue.delete_at(leading + index)
      else
        nil
      end
    else
      @queue.shift
    end

    @workers[req[:worker_id]] = {
      atime: Time.now,
      processing: entity
    }

    entity
  end

  def info
    value = {
      hosts: @hosts,
      holds: @holds,
      workers: @workers,
      queue: @queue
    }
  end

  def save_queue
    puts "------------ SAVE QUEUE" if @verbose
    File.open @qf, "w" do |f|
      Marshal.dump @queue, f
    end
    puts "------------ END SAVE QUEUE" if @verbose
  end

  def add_host req
    puts "------------ ADD HOST" if @verbose
    name = req[:name]
    @hosts[name] += 1
    @holds[name] = {
      name: name,
      power: req[:power],
      holds: req[:holds]
    } unless @holds[name]
    puts "------------ END ADD HOST" if @verbose
  end

  def del_host req
    puts "------------ DEL HOST" if @verbose
    name = req[:name]
    @hosts[name] -= 1
    if @hosts[name] <= 0
      @hosts.delete name
      @holds.delete name
    end
    @workers.delete req[:worker_id]
    puts "------------ END DEL HOST" if @verbose
  end

  def takeback req
    add [req[:resource]]
  end

  def main
    server = TCPServer.open(@config["port"])
    begin
      while sock = server.accept
        begin
          puts "------------ SOCK CONNECTED" if @verbose
          cmd = Marshal.load sock
          sock.close_read
          puts "=============> Request Accepted @ #{Time.now.to_s}"
          pp cmd if @verbose

          case cmd[:cmd]
          when :add
            puts "------------ CMD Add" if @verbose
            add cmd[:list]
            puts "------------ END CMD Add" if @verbose
          when :take
            puts "------------ CMD take" if @verbose
            add_host cmd unless @workers[cmd[:worker_id]]
            i = take cmd
            puts "------------ CMD took \n#{YAML.dump i}" if @verbose
            if i
              Marshal.dump i, sock
            else
              Marshal.dump({bye: true}, sock)
              del_host cmd
            end
            puts "------------ END CMD Add" if @verbose
          when :info
            puts "------------ CMD Info" if @verbose
            value = info
            Marshal.dump(value, sock)
            puts "------------ END CMD Info" if @verbose
          when :bye
            puts "------------ CMD bye" if @verbose
            del_host cmd
            puts "------------ END CMD bye" if @verbose
          when :die
            puts "------------ CMD die" if @verbose
            puts "------------ CMD die -- TAKEBACK #{cmd[:resource][:file]} (#{cmd[:resource][:source_prefix]})" if @verbose
            takeback cmd
            puts "------------ CMD die -- DEL HOST" if @verbose
            del_host cmd
            puts "------------ END CMD die" if @verbose
          end
          sock.close
          puts "=============> Request Closed"
          pp({queue_length: @queue.length})
        rescue => e
          puts "!! ----> Server raises error."
          puts e.full_message
        end
      end
    ensure
      save_queue
    end
  end
end

op = OptionParser.new
opts = {}
op.on("-t TYPE", "--type")
op.on("-v", "--verbose")

op.parse!(ARGV, into: opts)

mmff = MmFfT9.new(opts)
mmff.main
