class ServerMetrics::Memory < ServerMetrics::Collector
  # reports darwin units as MB
  DARWIN_UNITS = { "b" => 1/(1024*1024),
                   "k" => 1/1024,
                   "m" => 1,
                   "g" => 1024 }

  def build_report
    if solaris?
      solaris_memory
    elsif darwin?
      darwin_memory
    else
      linux_memory
    end
  end

  def linux_memory
    mem_info = {}
    `cat /proc/meminfo`.each_line do |line|
      _, key, value = *line.match(/^(\w+):\s+(\d+)\s/)
      mem_info[key] = value.to_i
    end

    # memory info is empty - operating system may not support it (why doesn't an exception get raised earlier on mac osx?)
    if mem_info.empty?
      raise "No such file or directory"
    end

    mem_info['MemTotal'] ||= 0
    mem_info['MemFree'] ||= 0
    mem_info['Buffers'] ||= 0
    mem_info['Cached'] ||= 0
    mem_info['SwapTotal'] ||= 0
    mem_info['SwapFree'] ||= 0

    mem_total = mem_info['MemTotal'] / 1024
    mem_free = (mem_info['MemFree'] + mem_info['Buffers'] + mem_info['Cached']) / 1024
    mem_used = mem_total - mem_free
    mem_percent_used = (mem_used / mem_total.to_f * 100).to_i

    swap_total = mem_info['SwapTotal'] / 1024
    swap_free = mem_info['SwapFree'] / 1024
    swap_used = swap_total - swap_free
    unless swap_total == 0
      swap_percent_used = (swap_used / swap_total.to_f * 100).to_i
    end

    # will be passed at the end to report to Scout
    report_data = Hash.new

    report_data[:size] = mem_total
    report_data[:used] = mem_used
    report_data[:avail] = mem_total - mem_used
    report_data[:used_percent] = mem_percent_used

    report_data[:swap_size] = swap_total
    report_data[:swap_used] = swap_used
    unless  swap_total == 0
      report_data[:swap_used_percent] = swap_percent_used
    end
    @data = report_data

  rescue Exception => e
    if e.message =~ /No such file or directory/
      error('Unable to find /proc/meminfo',%Q(Unable to find /proc/meminfo. Please ensure your operationg system supports procfs:
         http://en.wikipedia.org/wiki/Procfs)
      )
    else
      raise
    end
  end

  # Parses top output. Does not report swap usage.
  def darwin_memory
    report_data = Hash.new
    top_output = `top -l1 -n0 -u`
    mem = top_output[/^(?:Phys)?Mem:.+/i]

    mem.scan(/(\d+|\d+\.\d+)([bkmg])\s+(\w+)/i) do |amount, unit, label|
      case label
        when 'used'
          report_data[:used] =
              (amount.to_f * DARWIN_UNITS[unit.downcase]).round
        when 'free'
          report_data[:avail] =
              (amount.to_f * DARWIN_UNITS[unit.downcase]).round
      end
    end
    report_data[:size] = report_data[:used]+report_data[:avail]
    report_data[:used_percent] = ((report_data[:used].to_f/report_data[:size])*100).to_i
    @data = report_data
  end

  # Memory Used and Swap Used come from the prstat command. 
  # Memory Total comes from prtconf
  # Swap Total comes from swap -s
  def solaris_memory
    report_data = Hash.new

    prstat = `prstat -c -Z 1 1`
    prstat =~ /(ZONEID[^\n]*)\n(.*)/
    values = $2.split(' ')

    report_data[:used] = convert_to_mb(values[3])
    report_data[:swap_used]   = convert_to_mb(values[2])

    prtconf = `/usr/sbin/prtconf | grep Memory`

    prtconf =~ /\d+/
    report_data[:size] = $&.to_i
    report_data[:used_percent] = (report_data[:used] / report_data[:size].to_f * 100).to_i

    swap = `swap -s`
    swap =~ /\d+[a-zA-Z]\sused/
    swap_used = convert_to_mb($&)
    swap =~ /\d+[a-zA-Z]\savailable/
    swap_available = convert_to_mb($&)
    report_data[:swap_size] = swap_used+swap_available
    unless report_data[:swap_size] == 0
      report_data[:swap_used_percent] = (report_data[:swap_used] / report_data[:swap_size].to_f * 100).to_i
    end

    @data = report_data
  end

  # True if on solaris. Only checked on the first run (assumes OS does not change).
  def solaris?
    solaris = if @memory.has_key?(:solaris)
                memory(:solaris) || false
              else
                solaris = false
                begin
                  solaris = true if `uname` =~ /sunos/i
                rescue
                end
              end
    remember(:solaris => solaris)
    return solaris
  end

  # True if on darwin. Only checked on the first run (assumes OS does not change).
  def darwin?
    darwin = if @memory.has_key?(:darwin)
               memory(:darwin) || false
             else
               darwin = false
               begin
                 darwin = true if `uname` =~ /darwin/i
               rescue
               end
             end
    remember(:darwin => darwin)
    return darwin
  end
end
