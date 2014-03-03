require 'rbconfig'
require 'socket'

module ServerMetrics
  class SystemInfo

    def self.architecture
      RbConfig::CONFIG['target_cpu']
    end

    def self.os
      RbConfig::CONFIG['target_os']
    end

    def self.os_version
      `uname -r`.chomp
    end

    def self.num_processors
      if os =~ /(darwin|freebsd)/
        `sysctl -n hw.ncpu`.to_i
      elsif os =~ /linux/
        lines = File.read("/proc/cpuinfo").lines.to_a
        lines.grep(/^processor\s*:/i).size
      end
    rescue
      1
    end

    def self.timezone
      Time.now.zone
    end

    def self.timezone_offset
      Time.now.utc_offset/60/60
    end

    def self.hostname
      Socket.gethostname
    end

    def self.to_h
      {:architecture => architecture, :os=>os, :os_version=>os_version, :num_processors=>num_processors, :hostname=>hostname, :timezone=>timezone, :timezone_offset=>timezone_offset }
    end
  end
end

