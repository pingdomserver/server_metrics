require "rubygems"
require File.dirname(__FILE__)+ "/lib/server_metrics"
require "pry"

class Harness
  attr_accessor :num_runs, :latest_run

  def initialize
    @num_runs=0

    @collectors={:disks => ServerMetrics::Disk.new(), :cpu => ServerMetrics::Cpu.new(), :memory => ServerMetrics::Memory.new(), :network => ServerMetrics::Network.new(), :processes=>ServerMetrics::Processes.new(ServerMetrics::SystemInfo.num_processors)}

    @system_info = ServerMetrics::SystemInfo.to_h
  end

  def run
    collector_res={}
    @collectors.each_pair do |name, collector|
      collector_res[name] = collector.run
    end

    @latest_run = collector_res.merge(:system_info => @system_info)

    @num_runs +=1
  end
end

harness = Harness.new

harness.run
sleep 1
harness.run
pp harness.latest_run

#puts "starting"
#while(true) do
#  harness.run
#  puts "running at #{Time.now}"
#  File.open("server_metrics.json","w") do |f|
#    f.puts harness.latest_run
#  end
#  sleep 15
#end