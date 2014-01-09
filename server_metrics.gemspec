# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'server_metrics/version'

Gem::Specification.new do |spec|
  spec.name          = "server_metrics"
  spec.version       = ServerMetrics::VERSION
  spec.authors       = ["Andre Lewis", "Derek Haynes", "Matt Rose"]
  spec.email         = ["support@scoutapp.com"]
  spec.description   = %q{Collect information about disks, memory, CPU, networks, and processes}

  spec.homepage      = "http://scoutapp.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sys-proctable"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "mocha"
end
