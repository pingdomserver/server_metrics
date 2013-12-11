## 0.0.8.4

* normalize load (last minute, etc) by number of CPUs. This keeps the metrics in sync with Scout's server load plugin.

## 0.0.8.3

* fall back to assumption of 100 jiffies/sec if /proc/timer_list isn't available