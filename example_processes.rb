require "rubygems"
require File.dirname(__FILE__)+ "/lib/server_metrics"
require "pry"
require "awesome_print"


p = Scout::Processes.new(1)
puts "stating ..."
p.run
sleep 2
ap p.run
#p.get_overall_cpu
#Scout::ProcessList.add_cpu_time(Scout::ProcessList.group)
#puts "sleeping ..."
#sleep 1
#puts "#### overall"
#ap p.get_overall_cpu
#puts "#### individual processes"
#ap Scout::ProcessList.add_cpu_time(Scout::ProcessList.group)
