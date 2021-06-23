#!/usr/bin/ruby

require 'drb/drb'
require 'rinda/tuplespace'
require 'yaml'

CONFIG = YAML.load(File.read("mmffr.yaml"))

SERVER_ADDRESS = "druby://#{CONFIG["ts-addr"]}:#{CONFIG["ts-port"]}"

DRb.start_service(SERVER_ADDRESS, Rinda::TupleSpace.new)
puts DRb.uri
DRb.thread.join
