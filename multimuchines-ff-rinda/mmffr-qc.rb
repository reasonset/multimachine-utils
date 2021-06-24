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
  c = line.chomp.split("\t")
  ss = nil
  t = nil
  case c[1]
  when /(\d+):(\d+):(\d+)/
    ss = $1.to_i * 60 * 60 + $2.to_i * 60 + $3.to_i
  when /(\d+):(\d+)/
    ss = $1.to_i * 60 + $2.to_i
  when /(\d+)/
    ss = $1.to_i
  end
  case c[2] 
  when /(\d+):(\d+):(\d+)/
    t = ( $1.to_i * 60 * 60 + $2.to_i * 60 + $3.to_i) - (ss || 0)
  when /(\d+):(\d+)/
    t = ( $1.to_i * 60 + $2.to_i ) - (ss || 0)
  when /(\d+)/
    t = ( $1.to_i ) - (ss || 0)
  end

  dateprefix = RULES[CONFIG["source-style"]].(c[0])

  ts.write(["video", {
    ss: ss,
    t: t,
    source: c[0],
    dest: "#{CONFIG["outdir"].sub(%r:/$:, "")}/#{dateprefix}-#{c[3]}"
  }])
end