
# The base class for SystemMetrics collectors.
#
# Some collects inherit directly from Collector, and some inherit from MultiCollector.
# The difference: if you're collecting for an arbitrary number of instances (say, disks), use MultiCollector.
# Otherwise, use Collector.
#
# Relative to Scout's plugins, Collectors have a few differences:
#
# 1. simplified: no options parsing. simpler interface to reporting and memory (these methods only take a hash)
# 2. intended to persist in memory: a collector maintains its own memory. Reuse the same instance as many times as needed.
#    If you need to persist to disk, use the to_hash and from_hash methods.
#
module ServerMetrics
  class Collector
    attr_reader :collector_id
    attr_accessor :data, :error

    def initialize(options={})
      @options = options
      @data={}
      @memory={}
      @collector_id = self.class.name+'-'+@options.to_a.sort_by { |a| a.first }.flatten.join('-')
      @error=nil
    end

    def option(name)
      @options[name] || @options[name.is_a?(String) ? name.to_sym : String(name)]
    end

    def run
      @data={}
      build_report
      @data
    end

    def report(hash)
      @data.merge!(hash)
    end

    #   memory(:no_track)
    #   memory.delete(:no_track)
    #   memory.clear
    #
    def memory(name = nil)
      if name.nil?
        @memory
      else
        @memory[name] || @memory[name.is_a?(String) ? name.to_sym : String(name)]
      end
    end


    #   remember(name1: value1, name2: value2)
    #
    def remember(hash)
      @memory.merge!(hash)
    end

    #   counter(:rkbps, stats['rsect'] / 2, :per => :second)
    #   counter(:rpm, request_counter, :per => :minute)
    #   counter(:swap_ins, vmstat['pswpin'], :per => :second, :round => true)
    #
    def counter(name, value, options = {}, &block)
      current_time = Time.now

      if data = memory("_counter_#{name}")
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

          report(name => result)
        end
      end

      remember("_counter_#{name}" => {:time => current_time, :value => value})
    end

    # Convert strings containing 'T,G,M,or K' to MB. The result is a float only -- units are NOT returned
    def convert_to_mb(value)
      value = if value =~ /G/i
                value.to_f*1024.0
              elsif value =~ /M/i
                value.to_f
              elsif value =~ /K/i
                (value.to_f/1024.0)
              elsif value =~ /T/i
                (value.to_f*1024.0*1024.0)
              else
                value.to_f
              end
      ("%.1f" % [value]).to_f
    end

    #
    def normalize_key(key)
      (key.is_a?(String) ? key : key.to_s).downcase.gsub(" ", "_").gsub("%", "percent").to_sym
    end

    # returns a hash you can serialize and store on disk, or just hold onto and re-instantiate the plugin later.
    # Why you'd need to do this: to persist the memory (including counters) of a plugin instance.
    #
    # Plugin.from_hash(h) is the flipside of this: Plugin.from_hash(plugin.to_hash) gets you essentially the same instance
    #
    def to_hash
      {:options => @options, :memory => @memory, :data => @data, :plugin_id => @plugin_id}
    end

    # see to_hash. The hash should contain :options and :memory keys
    def self.from_hash(hash)
      c=Collector.new(hash[:options])
      c.instance_variable_set('@memory', hash[:memory])
      c.instance_variable_set('@data', hash[:data])
      c
    end

    def linux?
      RbConfig::CONFIG['target_os'] == 'linux'
    end

    def osx?
      RbConfig::CONFIG['target_os'] == 'darwin'
    end

  end
end