require 'sys/proctable'

# Collects information on processes. Groups processes running under the same command, and sums up their CPU & memory usage.
# CPU is calculated **since the last run**
#

class ServerMetrics::Processes

  def initialize(options={})
    @last_run
    @last_process_list
  end


  # This is the main method to call. It returns a hash of processes, keyed by the executable name.
  # Processes are returned either because they are a top 10 CPU consumer, or a top 10 memory consumer.
  #
  # The exact number or processes returned depends on the overlap between the two lists (cpu and memory consumers).
  # The list will always be between 10 and 20 items long.

  # {'mysqld' =>
  #     {
  #      :cmd => "mysqld",    # the command (without the path of arguments being run)
  #      :count    => 1,      # the number of these processes (grouped by the above command)
  #      :cpu      => 34,     # the total CPU usage of the processes
  #      :memory   => 2,      # the total memory usage of the processes
  #      :cmd_lines => ["cmd args1", "cmd args2"]
  #     },
  #  'apache' =>
  #     {
  #      ....
  #     }
  # }

  def run
    @processes = calculate_processes # returns a hash
    top_memory = get_top_processes(:memory, 10) # returns an array
    top_cpu = get_top_processes(:memory, 10) # returns an array

    # combine the two and index by cmd. The indexing process will remove duplicates
    result = (top_cpu + top_memory).inject(Hash.new) {|temp_hash,process_hash| temp_hash[process_hash[:cmd]] = process_hash; temp_hash }

    # An alternate approach is to return an array with two separate arrays. More explicit, but more verbose.
    #{
    #    :top_memory => get_top_processes(:memory, 10),
    #    :top_cpu => get_top_processes(:cpu, 10)
    #}
  end

  # called from run(). This method lists all the processes running on the server, groups them by command,
  # and calculates CPU time for each process. Since CPU time has to be calculated relative to the last sample,
  # the collector has to be run twice to get CPU data.
  def calculate_processes
    ## 1. get a list of all processes grouped by command
    processes = Sys::ProcTable.ps
    grouped = Hash.new
    processes.each do |proc|
      grouped[proc.comm] ||= {
          :count => 0,
          :raw_cpu => 0,
          :cpu => 0,
          :memory => 0,
          :uid => 0,
          :cmdlines => []
      }
      grouped[proc.comm][:count] += 1
      grouped[proc.comm][:raw_cpu] += proc.cutime + proc.cstime
      grouped[proc.comm][:memory] += proc.rss.to_f / 1024.0
      grouped[proc.comm][:uid] = proc.uid
      grouped[proc.comm][:cmdlines] << proc.cmdline if !grouped[proc.comm][:cmdlines].include?(proc.cmdline)
    end # processes.each

    ## 2. loop through each and calculate the CPU time. To do this, you need to compare the current values against the last run
    now = Time.now
    if @last_run and @last_process_list
      elapsed_time = now - @last_run # in seconds
      if elapsed_time >= 1
        grouped.each do |name, values|
          # if the process was around last time, calculate CPU relative to the last run. If the process wasn't around last time, return CPU since the process start
          if last_values = @last_process_list[name]
            cpu_since_last_sample = values[:raw_cpu] - last_values[:raw_cpu]
            grouped[name][:cpu] = (cpu_since_last_sample/(elapsed_time * ServerMetrics::SystemInfo.num_processors))*100
          else
            grouped[name][:cpu] = (values[:raw_cpu]/ServerMetrics::SystemInfo.num_processors)*100
          end
        end
      end
    end
    @last_process_list = grouped
    @last_run = now

    #grouped.select{|k,v| v[:cpu]} # only return processes that have been around for two cycles, so we've been been able to calculate the CPU
    grouped
  end

  # Can only be called after @processes is set. Based on @processes, calcuates the top {num} processes, as ordered by {order_by}.
  # Returns an array of hashes:
  # [{:cmd=>"ruby", :cpu=>30.0, :memory=>100, :uid=>1,:cmdlines=>[]}, {:cmd => ...} ]
  def get_top_processes(order_by, num)
    @processes.map { |key, hash| {:cmd => key}.merge(hash) }.sort { |a, b| a[order_by] <=> b[order_by] }.reverse[0...num]
  end

  # for persisting to a file -- conforms to same basic API as the Collectors do.
  # why not just use marshall? This is a lot more manageable written to the Scout agent's history file.
  def to_hash
    {:last_run=>@last_run, :last_process_list=>@last_process_list}
  end

  # for reinstantiating from a hash
  # why not just use marshall? this is a lot more manageable written to the Scout agent's history file.
  def self.from_hash(hash)
    p=new(hash[:options])
    p.instance_variable_set('@last_run', hash[:last_run])
    p.instance_variable_set('@last_process_list', hash[:last_process_list])
    p
  end

end
