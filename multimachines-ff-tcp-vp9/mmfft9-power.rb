#!/usr/bin/ruby
require 'optparse'
require 'dbm'

class MmFfT9Pw
  def initialize opts
    @xdg_state_dir = ENV["XDG_STATE_HOME"] || "#{ENV["HOME"]}/.local/state"
    @state_dir = "#{@xdg_state_dir}/reasonset/mmfft9"
    @drop_rate = opts[:"drop-rate"]&.to_f || 0.4
    @standard_title = opts[:"standard-title"]
    @type = opts[:type]&.to_s || "default"
    @opts = opts
    @avg = {}
  end

  attr :title, true
  attr :valid_avg

  def calc
    DBM.open("#{@state_dir}/#{@type}-title_power") do |dbm|
      overall_list = []
      dbm.each do |k, v|
        begin
          power_list = Marshal.load(v).sort
          next if power_list.empty?
          overall_list.concat power_list
          all_avg = power_list.sum / power_list.length
          power_list = power_list.drop_while {|i| i < (all_avg - all_avg * @drop_rate) }
          power_list = power_list.reverse.drop_while {|i| i > (all_avg + all_avg * @drop_rate) }
          valid_avg = power_list.empty? ? 0 : power_list.sum / power_list.length
          @avg[k] = valid_avg
        rescue =>e
          STDERR.puts "Error occured on #{k} (#{e})"
        end
      end

      if overall_list.empty?
        @valid_avg = 0
      else
        all_avg = overall_list.sum / overall_list.length
        power_list = overall_list.drop_while {|i| i < (all_avg - all_avg * @drop_rate) }
        power_list = overall_list.reverse.drop_while {|i| i > (all_avg + all_avg * @drop_rate) }
        valid_avg =  power_list.sum / power_list.length
  
        @valid_avg = valid_avg
      end
    end
    self
  end

  def rate title
    if !@avg[title]
      1
    elsif @standard_title
      @avg[@standard_title] / @avg[title].to_f
    else
      @power / @avg[title].to_f
    end
  end

  def power
    @standard_title ? @avg[@standard_title] || 0 : @valid_avg
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

    abort "No valid target mean power." if target_power.zero?

    keys = nil
    if @opts[:"sort-by-power"]
      keys = @avg.each_key.sort_by {|k| @avg[k] }
    else
      keys = @avg.each_key.sort_by {|k| k }
    end

    keys.each do |k|
      if @opts[:color]
        rate = (@avg[k] / target_power)
        ccode = if rate < 0.5
                  "\e[31m"
                elsif rate < 0.75
                  "\e[35m"
                elsif rate < 1
                  "\e[33m"
                elsif rate < 1.5
                  "\e[36m"
                elsif rate < 2
                  "\e[32m"
                else
                  "\e[34m"
                end
        printf("\e[1m%s\e[0m: %s%.4f\e[0m (%d)\n", k, ccode, rate, @avg[k])
      else
        printf("%s: %.4f (%d)\n", k, (@avg[k] / target_power), @avg[k])
      end
    end
  end

  def delete
    abort "No title given for delete." unless @title

    DBM.open("#{@state_dir}/#{@type}-title_power") do |dbm|
      abort "No power recorded for #{@title}" unless dbm.key?(@title)
      dbm.delete @title
    end
  end
end

if __FILE__ == $0
  op = OptionParser.new
  opts = {}
  op.on("-t TYPE", "--type")
  op.on("-r RATE", "--drop-rate")
  op.on("-p", "--sort-by-power")
  op.on("-c", "--color")
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
