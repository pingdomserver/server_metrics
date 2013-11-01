require 'sys/proctable'
require 'server_metrics/system_info'

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

    ## 1. get a list of all processes
    processes = Sys::ProcTable.ps.map{|p| ServerMetrics::Processes::Process.new(p) } # our Process object adds a method and adds some behavior

    ## 2. loop through each process and calculate the CPU time.
    # The CPU values returned by ProcTable are cumulative for the life of the process, which is not what we want.
    # So, we rely on @last_process_list to make this calculation. If a process wasn't around last time, we use it's cumulative CPU time so far, which will be accurate enough.
    now = Time.now
    aggregate_recent_cpu_of_all_processes = 1.0
    if @last_run && @last_process_list
      elapsed_time = now - @last_run # in seconds
      if elapsed_time >= 1
        processes.each do |p|
          if last_cpu = @last_process_list[p.pid]
            p.recent_cpu = (p.combined_cpu - last_cpu)/elapsed_time
          else
            p.recent_cpu = p.combined_cpu # this process wasn't around last time, so just use the cumulative CPU time so far
          end
          aggregate_recent_cpu_of_all_processes = aggregate_recent_cpu_of_all_processes + p.recent_cpu
        end
      end
    end

    ## 3. now hat we have the aggregate CPU usage for all processes, loop through the processes once more and set the recent_cpu_percentage.
    # note that this value is normalized for the number of processors
    processes.each {|p| p.recent_cpu_percentage =  (p.recent_cpu / aggregate_recent_cpu_of_all_processes) * 100.0 / ServerMetrics::SystemInfo.num_processors }

    ## 3. group by command and aggregate the CPU
    grouped = {}
    processes.each do |proc|
      grouped[proc.comm] ||= {
          :cpu => 0,
          :memory => 0,
          :count => 0,
          :cmdlines => []
      }
      grouped[proc.comm][:count]    += 1
      grouped[proc.comm][:cpu]      += proc.recent_cpu_percentage
      grouped[proc.comm][:memory]   += proc.rss.to_f / 1024.0
      grouped[proc.comm][:cmdlines] << proc.cmdline if !grouped[proc.comm][:cmdlines].include?(proc.cmdline)
    end # processes.each

    # {pid => cpu_snapshot, pid2 => cpu_snapshot ...}
    processes_to_store = processes.inject(Hash.new) do |hash, proc|
      hash[proc.pid] = proc.combined_cpu
      hash
    end

    @last_process_list = processes_to_store
    @last_run = now

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

  # a thin wrapper around Sys:ProcTable's ProcTableStruct. We're using it to add some fields and behavior.
  # Beyond what we're adding, it just passes through to its instance of ProcTableStruct
  class Process
    attr_accessor :recent_cpu, :recent_cpu_percentage # used to store the calculation of CPU since last sample
    def initialize(proctable_struct)
      @pts=proctable_struct
      @recent_cpu = 0
    end
    def combined_cpu
      # best thread I've seen on cutime vs utime & cstime vs stime: https://www.ruby-forum.com/topic/93176
      # trying the metric that doesn't include the consumption of child processes
      utime + stime
    end
    # delegate everything else to ProcTable::Struct
    def method_missing(sym, *args, &block)
      @pts.send sym, *args, &block
    end
  end
end
