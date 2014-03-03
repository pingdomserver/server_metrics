# Generates ruby-prof output based on the config options used by `scout_realtime` optimized for performance.
# ruby prof.rb
require "rubygems"
require "server_metrics"
require "ruby-prof"

class Harness
  attr_accessor :num_runs, :latest_run

  def initialize
    @num_runs=0

    @collectors={:disks => ServerMetrics::Disk.new(:ttl => 60), :cpu => ServerMetrics::Cpu.new(:skip_load => true), :memory => ServerMetrics::Memory.new(), :network => ServerMetrics::Network.new(), :processes=>ServerMetrics::Processes.new()}
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
RUNS = 300
result = RubyProf.profile do
  i=0
  while i < RUNS do
    i +=1
    harness.run
  end
end

# Print a graph profile to text
printer = RubyProf::GraphPrinter.new(result)
printer.print(STDOUT, {})
