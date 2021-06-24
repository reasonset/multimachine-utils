#!/usr/bin/ruby

require 'drb/drb'
require 'rinda/rinda'
require 'socket'
require 'yaml'

CONFIG = YAML.load(File.read("mmffr.yaml"))

# Merge site local config.
local_conf_path = (ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config") + "/reasonset/mmffr.yaml"
CONFIG.merge(YAML.load(File.read(local_conf_path))) if File.exist?(local_conf_path)

SERVER_ADDRESS = "druby://#{CONFIG["server-addr"]}:#{CONFIG["ts-port"]}"
MY_HOSTNAME = Socket.gethostname

MY_ADDRESS = Socket.ip_address_list.select {|i| File.fnmatch(CONFIG["if-filter"], i.ip_address) }[0].ip_address

DRb.start_service("druby://#{MY_ADDRESS}:0")
ts = Rinda::TupleSpaceProxy.new(DRbObject.new(nil, SERVER_ADDRESS))

while entry = ts.take(["video", nil])
  if File.exist?("mmffr-stop")
    begin
      hosts = File.foreach("mmffr-stop").map {|i| i.strip}
      if hosts.include? MY_HOSTNAME
        STDERR.puts("*****NOW STOPPING*****")
        exit
      end
    rescue
      nil
    end
  end
  begin
    command = ["-n"]
    command.concat(["-ss", entry[1][:ss].to_s]) if entry[1][:ss]
    command.concat(["-t", entry[1][:t].to_s]) if entry[1][:t]
    command.concat(["-i", entry[1][:source]])
    command.concat(CONFIG["codec"])
    command.push(entry[1][:dest])
    STDERR.puts "***GOING FFMPEG : ffmpeg #{command.join(" ")}"
    system("ffmpeg", *command)
  rescue
    puts "***!!!!!: #{entry.inspect}"
    raise
  end
end
