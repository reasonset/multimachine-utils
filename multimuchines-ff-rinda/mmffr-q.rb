#!/usr/bin/ruby

require 'drb/drb'
require 'rinda/rinda'
require 'yaml'

CONFIG = YAML.load(File.read("mmffr.yaml"))

# Merge site local config.
local_conf_path = (ENV["XDG_CONFIG_HOME"] || "#{ENV["HOME"]}/.config") + "/reasonset/mmffr.yaml"
CONFIG.merge(YAML.load(File.read(local_conf_path))) if File.exist?(local_conf_path)

SERVER_ADDRESS = "druby://#{CONFIG["server-addr"]}:#{CONFIG["ts-port"]}"

RULES = {
  "relive" => ->(path) {
    path.strip.sub(/^.*?_/, "").sub(/\.[^.]*$/, "") + "." + CONFIG["ext"] # title_date-time[_n].mp4
  },
  "coloros" => ->(path) {
    path.strip.sub(/^Record_/, "").sub(/_.*?$/, "") + "." + CONFIG["ext"]
  },
  "raw" => ->(path) {
    path.strip.sub(/\.[^.]*$/, "") + "." + CONFIG["ext"] # name.ext
  }
}

DRb.start_service
ts = Rinda::TupleSpaceProxy.new(DRbObject.new(nil, SERVER_ADDRESS))

File.foreach(ARGV[0]) do |line|
  next unless line
  next if line =~ /^\s*$/

  ts.write(["video", {
    source: line.strip,
    dest: "#{CONFIG["outdir"].sub(%r:/$:, "")}/#{RULES[CONFIG["source-style"]].(line)}"
  }])
end