require 'sys/proctable'

module Scout
  class Processes

    def initialize(num_processors)
      @last_run
      @last_process_list
      @num_processors = num_processors
      @last_utime
      @last_stime

    end

    # returns two arrays. The arrays have the top 10 memory using processes, and the top 10 CPU using processes.
    # The array elements are hashes that look like this:
    #
    # {:top_memory=>
    #    [
    #     {
    #      :commmand => "mysqld",
    #      :count    => 1,
    #      :cpu      => 34,
    #      :memory   => 2
    #     }, ...
    #   ],
    # :top_cpu=>
    #   [
    #     {
    #      :commmand => "mysqld",
    #      :count    => 1,
    #      :cpu      => 34,
    #      :memory   => 2
    #     }, ...
    #   ]
    #  }
    def run
      @processes = calculate_processes # returns a hash

      {
        :top_memory=>get_top_processes(:memory,10),
        :top_cpu=>get_top_processes(:cpu,10)
      }
    end


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
          :cmdlines =>[]
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
          grouped.each do |name,values|
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
      @processes.map{ |key,hash| {:cmd=>key}.merge(hash) } .sort{|a,b| a[order_by] <=> b[order_by] }.reverse[0...num-1]
    end

    #def get_overall_cpu
    #   res=nil
    #   now = Time.now
    #   t = ::Process.times
    #   if @last_run
    #     elapsed_time = now - @last_run
    #     if elapsed_time >= 1
    #       user_time_since_last_sample = t.utime - @last_utime
    #       system_time_since_last_sample = t.stime - @last_stime
    #       res = ((user_time_since_last_sample + system_time_since_last_sample)/(elapsed_time * @num_processors))*100
    #     end
    #   end
    #   @last_utime = t.utime
    #   @last_stime = t.stime
    #   @last_run = now
    #   return res
    #end

  end # class ProcessList

end # module Scout

