require 'server_metrics/version'
require 'server_metrics/collector'
require 'server_metrics/multi_collector'
require 'server_metrics/system_info'

Dir[File.dirname(__FILE__) + '/server_metrics/collectors/*.rb'].each {|file| require file }
