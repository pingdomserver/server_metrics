require "rubygems"

$LOAD_PATH.unshift(File.expand_path(__FILE__), "lib") # set the loadpath for convenience during development
require "server_metrics"

require "pry"
require "awesome_print"

p = ServerMetrics::Processes.new(1)
puts "stating ..."
p.run
sleep 1
ap p.run

#p.get_overall_cpu
#ServerMetrics::ProcessList.add_cpu_time(ServerMetrics::ProcessList.group)
#puts "sleeping ..."
#sleep 1
#puts "#### overall"
#ap p.get_overall_cpu
#puts "#### individual processes"
#ap ServerMetrics::ProcessList.add_cpu_time(ServerMetrics::ProcessList.group)
