# BQUEUE DEFINITIONS
#
# This file must be sourced after the queue config file
#
# 2020 Mauricio Asenjo
# version 2.1rc2


# workers scripts directory
workerdir="workers"
workscript=./$workerdir/$work

# log files: 
logdir="$name/logs"
logfile="queue."$(hostname -s)".log"
logprocfile="process."$(hostname -s)".log"
deliver_lock="$name/deliver.lock"
process_lock="$name/process.lock"

#pid file
PID_file=$name/$name"."$(hostname -s)".pid"

## queue directory definitions

# Is in_queue is set, set the "out" dir of the specified queue as "in"
# otherwise, set it to the internal default
if [ -z $in_queue ]
then
    in=$name"/in"
else
    in=$in_queue"/out"
fi

# Is out_queue is set, set the "in" dir of the specified queue as "out"
# otherwise, set it to the internal default
if [ -z $out_queue ]
then
    out=$name"/out" 
else 
    out=$out_queue"/in"
fi

# subdir for the jobs taken for delivery
deliver=$name/"deliver"
# subdir of the jobs being executed
process=$name/"process"
# subdir of the jobs that failed execution
failed=$name/"failed"
# subdir of the jobs that finished successfully
finished=$name/"finished"
# subdir to place external check scripts:
extcheck=$name/"extcheck.d"
