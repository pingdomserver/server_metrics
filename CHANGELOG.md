# 1.2.10

* Fix comm name detection with parenthesis

# 1.2.9.1

* Ruby 1.8.7 fix

## 1.2.9

* Add support for dockerized metric gathering

## 1.2.8

* compatibility with Ruby 1.8.5 and 1.8.6

## 1.2.7

* Revert vz changes from 1.2.6

## 1.2.6

* If '^/vz' is detected in the mount output, add /dev/simfs to the device list for disk collector

## 1.2.5

* Gather all non-loopback network interfaces by default.

## 1.2.4

* Collecting OSX disk capacity metrics

## 1.2.3

* Skipping mapped devices in disk collector

## 1.2.2

* Setting LC_ALL for disk
* More forgiving #linux? check

## 1.2.1

* Fix for OSX Memory to support 'unused' in addition to 'free'

## 1.2.0

Performance related:

* Using `Dir#glob` vs. `Dir#foreach`
* Using `File#read` vs. `cat FILE`. 
* Removing commented out and unused elements from `SysLite::ProcTable`
* Removed method_missing logic in `Processes::Process` to access the `ProcTableStruct`
* `Disk` added caching logic via a `@option[:ttl]` to execute slow system calls at a lower interval (ex: ev 60 seconds)
* `String#lines#to_a` vs. `String#split('\n')` (faster)

## 1.1.1

* Handling Infinite and NaN Process CPU Usage.
* Case-insensitive process count grep, returning 1 processor vs. nil on rescue.

## 1.1.0

* sys/proctable is no longer a dependency in the gemspec.
* Linux systems with the /proc filesystem will return all process metrics
* other systems with sys/proctable installed will try to use sys/proctable, wnd will generally return a list of process names and counts (but no memory/cpu)
* all other systems: no process info returned

## 1.0.3

* Assuming 100 jiffies/second vs. reading from /proc/timer_list

## 1.0.2

* Also grouping under kthread (one d vs. 2 ds)

## 1.0.1

* Grouping kthreadd's children together under the comm "kthreadd"

## 0.1.0

* Optimization for collecting processes on Linux

## 0.0.9.0

* Reporting process memory in MB, not in page size. 
* When determining process cpu usage, caching number of processors.

## 0.0.8.9

* Fix for top cpu-consuming processes in the process list

## 0.0.8.8

* Fix for LVM-mapped disk IO stats

## 0.0.8.5

* Mac per-process memory and per-process CPU reports 0s instead of throwing an exception (Mac only)

## 0.0.8.4

* Normalize load (last minute, etc) by number of CPUs. This keeps the metrics in sync with Scout's server load plugin.

## 0.0.8.3

* Fall back to assumption of 100 jiffies/sec if /proc/timer_list isn't available
