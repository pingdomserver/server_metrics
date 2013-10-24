# SystemMetrics

Collects key metrics on CPU, disks, memory, network interfaces, and processes.

## Use

    $ gem install server_metrics

    require 'server_metrics'
    cpu=Scout::Cpu.new
    cpu.run
    pp cpu.data.inspect

    # same with:

    Scout::Disk.new
    Scout::Memory.new
    Scout::Network.new

    # also see:

    Scout::SystemInfo.to_hash

## Creating a new collector

Inherit from either Collector (if you're generating just one set of data), or MultiCollector (if you will be generating N
sets of data -- for example if you're monitoring disks or network interfaces).

## TODOs

* better mac compatibility
* more test coverage
* rethink module hierarchy

