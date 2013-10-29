# MultiCollector is a special case of Collector that returns N metric bundles. For example, Disk uses MultiCollector:
# you can have any number of mounted disks. MultiCollector generates a nested result:
#{
#    "dev/disk1" => {
#        "Avail" => 295936.0,
#        "Capacity" => 38.0,
#        ...
#    },
#    "dev/disk2" => {
#        "Avail" => 295936.0,
#        "Capacity" => 38.0,
#         ...
#    }
#
#}

module ServerMetrics
  class MultiCollector < ServerMetrics::Collector

    # report("/dev/desk2", :key=>value)
    def report(bundle_name, values)
      @data[bundle_name] ||= {}
      @data[bundle_name].merge!(values)
    end

    # for MultiCollector, Memory takes an additional argument specifying the sub-hash (bundle) in memory.
    # The bundle name corresponds to the disk/network/whatever we're storing memory for.
    #
    #   memory("/dev/desk2", :no_track)
    #   memory.delete("/dev/desk2",:no_track)
    #   memory.clear("/dev/desk2")
    #
    def memory(bundle_name, name)
      @memory[bundle_name] ||= {}
      if name.nil?
        @memory[bundle_name]
      else
        @memory[bundle_name][name] || @memory[name.is_a?(String) ? name.to_sym : String(name)]
      end
    end

    # just like the memory function, "remember" takes an additional argument to partition memory by bundle name
    def remember(bundle_name, hash)
      @memory[bundle_name] ||= {}
      @memory[bundle_name].merge!(hash)
    end

    # counters are also partitioned by bundle name
    #
    #   counter("/dev/desk2", :rkbps, stats['rsect'] / 2, :per => :second)
    #   counter("/dev/desk2", :rpm, request_counter, :per => :minute)
    #   counter("/dev/desk2", :swap_ins, vmstat['pswpin'], :per => :second, :round => true)
    #
    def counter(bundle_name, name, value, options = {}, &block)
      current_time = Time.now

      if data = memory(bundle_name, "_counter_#{name}")
        last_time, last_value = data[:time], data[:value]
        elapsed_seconds = current_time - last_time

        # We won't log it if the value has wrapped or enough time hasn't
        # elapsed
        if value >= last_value && elapsed_seconds >= 1
          if block
            result = block.call(last_value, value)
          else
            result = value - last_value
          end

          case options[:per]
            when :second, 'second'
              result = result / elapsed_seconds.to_f
            when :minute, 'minute'
              result = result / elapsed_seconds.to_f * 60.0
            else
              raise "Unknown option for ':per': #{options[:per].inspect}"
          end

          if options[:round]
            result = (result * (10 ** options[:round])).round / (10 ** options[:round]).to_f
          end
          report(bundle_name, name => result)
        end
      end

      remember(bundle_name, "_counter_#{name}" => {:time => current_time, :value => value})
    end

  end
end

