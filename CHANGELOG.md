## 0.0.8.8

* fix for LVM-mapped disk IO stats

## 0.0.8.5

* Mac per-process memory and per-process CPU reports 0s instead of throwing an exception (Mac only)

## 0.0.8.4

* normalize load (last minute, etc) by number of CPUs. This keeps the metrics in sync with Scout's server load plugin.

## 0.0.8.3

* fall back to assumption of 100 jiffies/sec if /proc/timer_list isn't available