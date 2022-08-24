#!/bin/sh
echo        0 | tee /sys/kernel/debug/sched/tunable_scaling
echo 16000000 | tee /sys/kernel/debug/sched/latency_ns
scale=`echo "v=1000000*(1+(l(\`nproc\`)/l(2)));scale=0;v/1" | bc -l`
echo $((scale * 3 / 4)) | tee /sys/kernel/debug/sched/min_granularity_ns
echo $scale             | tee /sys/kernel/debug/sched/wakeup_granularity_ns
echo 0 | tee /sys/kernel/debug/sched/burst_preempt
echo 4 | tee /sys/kernel/debug/sched/burst_reduction

