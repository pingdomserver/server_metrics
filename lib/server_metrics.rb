$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'scout/version'
require 'scout/collector'
require 'scout/multi_collector'
require 'scout/system_info'

Dir[File.dirname(__FILE__) + '/scout/collectors/*.rb'].each {|file| require file }
