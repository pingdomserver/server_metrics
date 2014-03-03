# This is a special-purpose version Sys::Proctable, optimized for collecting fewer metrics (but running faster) on Linux only
# In process.rb, we conditionally use this class when the host OS is Linux.

# The Sys module serves as a namespace only.
module SysLite

  # The ProcTable class encapsulates process table information.
  class ProcTable

    # Error typically raised if the ProcTable.ps method fails.
    class Error < StandardError; end

    # There is no constructor
    private_class_method :new

    # The version of the sys-proctable library
    VERSION = '0.9.3'

    private
    
    # Handles a special case on Ubuntu - kthreadd generates many children (200+). 
    # These are aggregated together and reported as a single process, kthreadd.
    #  
    # Examples child process names:
    #
    # watchdog/5  
    # kworker/10:1 
    # kworker/10:1H
    # ksoftirqd/8 
    # migration/10 
    # scsi_eh_2 
    # flush-9:2 
    # kswapd0
    @kthreadd = nil # the ProcTableStruct representing kthreadd

    @fields = [
        'cmdline',     # Complete command line
        'cwd',         # Current working directory
        'exe',         # Actual pathname of the executed command
        'pid',         # Process ID
        'comm',        # Filename of executable
        'ppid',        # Parent process ID
        'utime',       # Number of user mode jiffies
        'stime',       # Number of kernel mode jiffies
        'cutime',      # Number of children's user mode jiffies
        'cstime',      # Number of children's kernel mode jiffies
        'vsize',       # Virtual memory size in bytes
        'rss',         # Resident set size
        'name',        # Process name
    ]

    public

    ProcTableStruct = Struct.new('ProcTableStructLite', *@fields)

    # In block form, yields a ProcTableStruct for each process entry that you
    # have rights to. This method returns an array of ProcTableStruct's in
    # non-block form.
    #
    # If a +pid+ is provided, then only a single ProcTableStruct is yielded or
    # returned, or nil if no process information is found for that +pid+.
    #
    # Example:
    #
    #   # Iterate over all processes
    #   ProcTable.ps do |proc_info|
    #      p proc_info
    #   end
    #
    #   # Print process table information for only pid 1001
    #   p ProcTable.ps(1001)
    #
    #--
    #  It's possible that a process could terminate while gathering
    #  information for that process. When that happens, this library
    #  will simply skip to the next record. In short, this library will
    #  either return all information for a process, or none at all.
    #
    def self.ps(pid=nil)
      array  = block_given? ? nil : []
      struct = nil
      raise TypeError unless pid.is_a?(Fixnum) if pid
      
      Dir.chdir("/proc")
      Dir.glob("[0-9]*").each do |file|
        next unless file.to_i == pid if pid

        struct = ProcTableStruct.new

        # Get /proc/<pid>/stat information
        stat = IO.read("/proc/#{file}/stat") rescue next

        # Deal with spaces in comm name. Courtesy of Ara Howard.
        re = %r/\([^\)]+\)/
        comm = stat[re]
        comm.tr!(' ', '-')
        stat[re] = comm

        stat = stat.split

        struct.pid         = stat[0].to_i
        # Remove parens. Note this could be overwritten in #get_comm_group_name.
        struct.comm        = stat[1].tr('()','')
        struct.ppid        = stat[3].to_i
        struct.utime       = stat[13].to_i
        struct.stime       = stat[14].to_i
        struct.rss         = stat[23].to_i
        
        # don't report kthreadd chidren individually - aggregate into the parent.
        if kthreadd_child?(struct.ppid)
          @kthreadd.utime += struct.utime
          @kthreadd.stime += struct.stime
          @kthreadd.rss += struct.rss
          next
        elsif !@kthreadd and %w(kthread kthreadd).include?(struct.comm)
          @kthreadd = struct
          next
        end
        
        struct.freeze # This is read-only data

        if block_given?
          yield struct
        else
          array << struct
        end
      end # Dir.glob

      if pid
        struct
      else 
        array << @kthreadd if @kthreadd # not added when iterating.
        array
      end
    end

    # Returns an array of fields that each ProcTableStruct will contain. This
    # may be useful if you want to know in advance what fields are available
    # without having to perform at least one read of the /proc table.
    #
    # Example:
    #
    #   Sys::ProcTable.fields.each{ |field|
    #      puts "Field: #{field}"
    #   }
    #
    def self.fields
      @fields
    end

    private
    
    # True if the process's parent process id is kthreadd.
    def self.kthreadd_child?(ppid)
      @kthreadd and @kthreadd.pid == ppid
    end

    # Calculate the percentage of memory usage for the given process.
    #
    def self.get_pctmem(rss)
      return nil unless @mem_total
      page_size = 4096
      rss_total = rss * page_size
      sprintf("%3.2f", (rss_total.to_f / @mem_total) * 100).to_f
    end

    # Calculate the percentage of CPU usage for the given process.
    #
    def self.get_pctcpu(utime, start_time)
      return nil unless @boot_time
      hertz = 100.0
      utime = (utime * 10000).to_f
      stime = (start_time.to_f / hertz) + @boot_time
      sprintf("%3.2f", (utime / 10000.0) / (Time.now.to_i - stime)).to_f
    end
  end
end
