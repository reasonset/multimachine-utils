#!/usr/bin/ruby

require 'drb/drb'
require 'rinda/tuplespace'
require 'yaml'

CONFIG = YAML.load(File.read("mmffr.yaml"))

# Merge site local config.
local_conf_path = (ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config") + "/reasonset/mmffr.yaml"
CONFIG.merge(YAML.load(File.read(local_conf_path))) if File.exist?(local_conf_path)

SERVER_ADDRESS = "druby://#{CONFIG["ts-addr"]}:#{CONFIG["ts-port"]}"

DRb.start_service(SERVER_ADDRESS, Rinda::TupleSpace.new)
puts DRb.uri
DRb.thread.join
