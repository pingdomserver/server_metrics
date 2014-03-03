# Collects Disk metrics on eligible filesystems. Reports a hash of hashes, with the first hash keyed by device name.
#
# TODO: Currently, this reports on devices that begins with /dev as listed by `mount`. Revisit this.
# TODO: relies on /proc/diskstats, so not mac compatible. Figure out mac compatibility
#
class ServerMetrics::Disk < ServerMetrics::MultiCollector

  def build_report
    ENV['LANG'] = 'C' # forcing English for parsing
    
    @disk_stats = File.read("/proc/diskstats").lines.to_a

    devices.each do |device|
      get_sizes(device) # does its own reporting
      get_stats(device) if linux? # does its own reporting
    end
  end
  
  # System calls are slow. Read once every minute and not on every innvocation. 
  def df_output
    if @last_df_output.nil? or @last_df_output < (Time.now-@options[:ttl].to_i*60)
      @last_df_output = Time.now
      @df_output = `df -Pkh`.lines.to_a
    else
      @df_output
    end
  end
  
  # System calls are slow. Read once every minute and not on every innvocation. 
  def devices
    if @devices.nil? or @last_devices_output < (Time.now-@options[:ttl].to_i*60)
      @last_devices_output = Time.now
      @devices = `mount`.split("\n").grep(/^\/dev/).map{|l|l.split.first} # any device that starts with /dev    
    else
      @devices
    end
  end

  # called from build_report for each device
  def get_sizes(device)
    header_line=df_output.first
    headers = header_line.split(/\s+/,6) # limit to 6 columns - last column is "mounted on"
    parsed_lines=[] # Each line will look like {"%iused" => "38%","Avail" => "289Gi", "Capacity=> "38%", "Filesystem"=> "/dev/disk0s2","Mounted => "/", "Size" => "465Gi", "Used" => "176Gi", "ifree" => "75812051", "iused"  => "46116178"}

    df_output[1..df_output.size-1].each do |line|
      values=line.split(/\s+/,6)
      parsed_lines<<Hash[headers.zip(values)]
    end

    # select the right line
    hash = parsed_lines.select{|l| l["Filesystem"] == device}.first
    result = {}
    hash.each_pair do |key,value|
      key=normalize_key(key) # downcase, make a symbol, etc
      value = convert_to_mb(value) if [:avail, :capacity, :size, :used].include?(key)
      result[key]=value
    end

    report(device, result)
  end

  # called from build_report for each device
  def get_stats(device)
    stats = iostat(device)

    if stats
      counter(device, :rps,   stats['rio'],        :per => :second)
      counter(device, :wps,   stats['wio'],        :per => :second)
      counter(device, :rps_kb, stats['rsect'] / 2,  :per => :second)
      counter(device, :wps_kb, stats['wsect'] / 2,  :per => :second)
      counter(device, :utilization,  stats['use'] / 10.0, :per => :second)
      # Not 100% sure that average queue length is present on all distros.
      if stats['aveq']
        counter(device, :average_queue_length,  stats['aveq'], :per => :second)
      end

      if old = memory(device, "stats")
        ios = (stats['rio'] - old['rio']) + (stats['wio']  - old['wio'])

        if ios > 0
          await = ((stats['ruse'] - old['ruse']) + (stats['wuse'] - old['wuse'])) / ios.to_f

          report(device, :await => await)
        end
      end

      remember(device, "stats" => stats)
    end
  end

  private
  COLUMNS = %w(major minor name rio rmerge rsect ruse wio wmerge wsect wuse running use aveq)

  # Returns the /proc/diskstats line associated with device name +dev+. Logic:
  #
  # * If an exact match of the specified device is found, returns it.
  # * If there isn't an exact match but there are /proc/diskstats lines that are included in +dev+,
  #   returns the first matching line. This is needed as the mount output used to find the default device doesn't always
  #   match /proc/diskstats output.
  def iostat(dev)

    # if this is a mapped device, translate it into the mapped name for lookup in @disk_stats
    if dev =~ %r(^/dev/mapper/)
      name_to_find = File.readlink(dev).split("/").last rescue dev
    else
      name_to_find = dev
    end

    # narrow our @disk_stats down to a list of possible devices
    possible_devices = @disk_stats.map { |line|
      Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]
    }.select{|entry| name_to_find.include?(entry['name']) }

    # return an exact match (preferred) or a partial match. If neither exist, nil will be returned
    return possible_devices.find { |entry| name_to_find == entry['name'] } || possible_devices.first
  end

  def normalize_key(key)
    key = "Used Percent" if /capacity|use.*%|%.*use/i === key
    key.downcase.gsub(" ", "_").to_sym
  end
end
