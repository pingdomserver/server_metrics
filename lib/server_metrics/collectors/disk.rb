# Collects Disk metrics on eligible filesystems. Reports a hash of hashes, with the first hash keyed by device name.
#
# TODO: Currently, this reports on devices that begins with /dev as listed by `mount`. Revisit this.
# TODO: relies on /proc/diskstats, so not mac compatible. Figure out mac compatibility
#
class ServerMetrics::Disk < ServerMetrics::MultiCollector

  def build_report
    @df_output = `df -h`.split("\n")
    @devices = `mount`.split("\n").grep(/^\/dev/).map{|l|l.split.first} # any device that starts with /dev

    @devices.each do |device|
      get_sizes(device) # does its own reporting
      get_stats(device) if linux? # does its own reporting
    end
  end

  # called from build_report for each device
  def get_sizes(device)
    ENV['LANG'] = 'C' # forcing English for parsing

    header_line=@df_output.first
    num_columns = header_line.include?("iused") ? 9 : 6 # Mac has extra columns
    headers = header_line.split(/\s+/,num_columns)
    parsed_lines=[] # Each line will look like {"%iused" => "38%","Avail" => "289Gi", "Capacity=> "38%", "Filesystem"=> "/dev/disk0s2","Mounted => "/", "Size" => "465Gi", "Used" => "176Gi", "ifree" => "75812051", "iused"  => "46116178"}

    @df_output[1..@df_output.size-1].each do |line|
      values=line.split(/\s+/,num_columns)
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
  # * If there are no matches but an LVM is used, returns the line matching "dm-0".
  def iostat(dev)
    # if a LVM is used, `mount` output doesn't map to `/diskstats`. In this case, use dm-0 as the default device.
    lvm = nil
    retried = false
    possible_devices = []
    begin
      %x(cat /proc/diskstats).split(/\n/).each do |line|
        entry = Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]
        possible_devices << entry if dev.include?(entry['name'])
        lvm = entry if (@default_device_used and 'dm-0'.include?(entry['name']))
      end
    rescue Errno::EPIPE
      if retried
        raise
      else
        retried = true
        retry
      end
    end
    found_device = possible_devices.find { |entry| dev == entry['name'] } || possible_devices.first
    return found_device || lvm
  end

  def normalize_key(key)
    key = "Used Percent" if /capacity|use.*%|%.*use/i === key
    key.downcase.gsub(" ", "_").to_sym
  end
end
