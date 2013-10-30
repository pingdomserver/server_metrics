require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

task :default => :test

# put the current packaged version of the gem in dropbox
desc "copies the current packaged .gem file to https://dl.dropboxusercontent.com/u/18554/server_metrics.gem"
task :dropbox do

  path=File.dirname(__FILE__)+"/pkg/server_metrics-#{ServerMetrics::VERSION}.gem"
  if !File.exists?(path)
    puts "Doesn't exist: #{path}. Try rake build"
    exit(0)
  end

  FileUtils.copy(path, "/Users/andre/Dropbox/Public/")
  puts "wget https://dl.dropboxusercontent.com/u/18554/server_metrics-#{ServerMetrics::VERSION}.gem; gem install server_metrics"
end
