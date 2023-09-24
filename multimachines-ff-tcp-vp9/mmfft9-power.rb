#!/usr/bin/ruby
require 'optparse'
require 'dbm'

class MmFfT9Pw
  def initialize opts
    @xdg_state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @state_dir = "#{@xdg_state_dir}/reasonset/mmfft9"
    @drop_rate = opts[:"drop-rate"]&.to_f || 0.4
    @avg = {}
  end

  attr :title, true

  def calc
    DBM.open("#{@state_dir}/title_power") do |dbm|
      dbm.each do |k, v|
        begin
          power_list = Marshal.load(v).sort
          next if power_list.empty?
          all_avg = power_list.sum / power_list.length
          power_list = power_list.drop_while {|i| i < (all_avg - all_avg * @drop_rate) }
          power_list = power_list.reverse.drop_while {|i| i > (all_avg + all_avg * @drop_rate) }
          valid_avg = power_list.empty? ? 0 : power_list.sum / power_list.length
          @avg[k] = valid_avg
        rescue =>e
          STDERR.puts "Error occured on #{k} (#{e})"
        end
      end
    end
    self
  end

  def out
    if @avg.empty?
      abort "No power is recorded yet."
    end

    target_power = if @title
      @avg[@title].to_f or abort "No power recorded for #{@title}"
    else
      (@avg.each_value.sum / @avg.length).to_f
    end

    abort "No valid target average power." if target_power.zero?

    @avg.each do |k, v|
      printf("%s: %.4f (%d)\n", k, (v / target_power), v)
    end
  end

  def delete
    abort "No title given for delete." unless @title

    DBM.open("#{@state_dir}/title_power") do |dbm|
      abort "No power recorded for #{@title}" unless dbm.key?(@title)
      dbm.delete @title
    end
  end
end

if __FILE__ == $0
  op = OptionParser.new
  opts = {}
  op.on("-r RATE", "--drop-rate")
  op.on("-D", "--delete")
  op.parse!(ARGV, into: opts)

  mmff = MmFfT9Pw.new(opts)
  mmff.title = ARGV.shift
  if opts[:delete]
    mmff.delete
  else
    mmff.calc.out
  end
end