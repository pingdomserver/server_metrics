require "server_metrics/system_info"

class ServerMetrics::Network < ServerMetrics::MultiCollector

  def build_report
    if linux?
      lines = File.read("/proc/net/dev").lines.to_a[2..-1]
      interfaces = []
      lines.each do |line|
        iface, rest = line.split(':', 2).collect { |e| e.strip }
        interfaces << iface
        next if iface =~ /lo/
        found = true
        cols = rest.split(/\s+/)

        bytes_in, packets_in, bytes_out, packets_out = cols.values_at(0, 1, 8, 9).collect { |i| i.to_i }

        counter(iface, :bytes_in, bytes_in.to_f / 1024.0 * 8.0, :per => :second, :round => 2)
        counter(iface, :packets_in, packets_in.to_f, :per => :second, :round => 2)
        counter(iface, :bytes_out, bytes_out.to_f / 1024.0 * 8.0, :per => :second, :round => 2)
        counter(iface, :packets_out, packets_out.to_f, :per => :second, :round => 2)
      end
    end
  end
end
