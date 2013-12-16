require 'rubygems'
require 'rubygems/command'
require 'rubygems/dependency_installer'

begin
  Gem::Command.build_args = ARGV
rescue NoMethodError
end

inst = Gem::DependencyInstaller.new

begin
  inst.install "sys-proctable" if File.exist?('/proc')
rescue
  exit(1)
end

File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w") do |f| # create a dummy rakefile to indicate success
  f.write("task :default\n")
end
