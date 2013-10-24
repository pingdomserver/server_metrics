# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scout/version'

Gem::Specification.new do |spec|
  spec.name          = "server_metrics"
  spec.version       = ServerMetrics::VERSION
  spec.authors       = ["Andre Lewis"]
  spec.email         = ["andre@scoutapp.com"]
  spec.description   = %q{Collect information about disks, memory, CPU, etc}
  spec.summary       = %q{For use with the Scout agent}
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
