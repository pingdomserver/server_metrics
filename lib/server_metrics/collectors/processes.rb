require 'sys/proctable'

# Collects information on processes. Groups processes running under the same command, and sums up their CPU & memory usage.
# CPU is calculated **since the last run**
#

class ServerMetrics::Processes

  def initialize(num_processors)
    @num_processors = num_processors
    @last_run
    @last_process_list
  end

  # This is the main method to call. It returns a hash of two arrays.
  # The arrays have the top 10 memory using processes, and the top 10 CPU using processes, respectively.
  # The array elements are hashes that look like this:
  #
  # {:top_memory=>
  #    [
  #     {
  #      :cmd => "mysqld",    # the command (without the path of arguments being run)
  #      :count    => 1,      # the number of these processes (grouped by the above command)
  #      :cpu      => 34,     # the total CPU usag of the processes
  #      :memory   => 2       # the total memory usage of the processes
  #     }, ...
  #   ],
  # :top_cpu=>
  #   [
  #     {
  #      :cmd => "mysqld",
  #      :count    => 1,
  #      :cpu      => 34,
  #      :memory   => 2
  #     }, ...
  #   ]
  #  }
  def run
    @processes = calculate_processes # returns a hash

    {
        :top_memory => get_top_processes(:memory, 10),
        :top_cpu => get_top_processes(:cpu, 10)
    }
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
          if last_values = @last_process_list[name]
            cpu_since_last_sample = values[:raw_cpu] - last_values[:raw_cpu]
            grouped[name][:cpu] = (cpu_since_last_sample/(elapsed_time * @num_processors))*100
          else
            grouped.reject!(name) # no data from last run. don't report anything.
          end
        end
      end
    end
    @last_process_list = grouped
    @last_run = now
    grouped
  end

  # Can only be called after @processes is set. Based on @processes, calcuates the top {num} processes, as ordered by {order_by}.
  # Returns an array of hashes:
  # [{:cmd=>"ruby", :cpu=>30.0, :memory=>100, :uid=>1,:cmdlines=>[]}, {:cmd => ...} ]
  def get_top_processes(order_by, num)
    @processes.map { |key, hash| {:cmd => key}.merge(hash) }.sort { |a, b| a[order_by] <=> b[order_by] }.reverse[0...num-1]
  end

  # for persisting to a file -- conforms to same basic API as the Collectors do.
  # why not just use marshall? this is a lot more manageable written to the Scout agent's history file.
  def to_h
    {:last_run=>@last_run, :last_process_list=>@last_process_list}
  end

  # for reinstantiating from a hash
  # why not just use marshall? this is a lot more manageable written to the Scout agent's history file.
  def self.from_hash(hash,num_processors)
    p=ServerMetrics::Processes.new(num_processors)
    p.instance_variable_set('@last_run', hash[:last_run])
    p.instance_variable_set('@last_process_list', hash[:last_process_list])
    p
  end

end
