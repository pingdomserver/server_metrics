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