#!/bin/bash
#
# BQUEUE
#
# Bash queueing 
# job processing using files in dirs as queues
# "in" is the dir where the new jobs arrives (text files)
# "processing" is the queue of active jobs
# "failed" is where we place the failed jobs
# "finished" is where we place the finished jobs
#
#   Gets a config file as a parameter to implement the queue
# 2020 Mauricio Asenjo
version="2.1rc5"

# Set the shell to terminate on error if a variable is unset
set -u

# Config file validation

if [ -z $1 ]
then
    echo "USAGE: "$0" <config_file>"
    exit 1
fi
config_file=$1
if [ ! -f $config_file ]
then
    echo "ERROR: File: "$config_file" not found, exiting"
    exit 2
fi

source ./bqueue_utils.sh
source ./$config_file
source ./bqueue_defs.sh


if [ ! -d $workerdir ]
then 
    echo "ERROR: $workerdir directory not found, exiting"
    exit 1
fi

export name batch threads work retry new_pooling in_queue out_queue extcheck


#initialize directories
for dir in $deliver $process $failed $finished $logdir $extcheck
do
    init_dir $dir
    if [ $? -ne 0 ]
    then
        msg="ERROR: directory $dir could not be created. Exiting"
        echo $msg
        log $mg
        exit 8
    fi
done
# Is in_queue is set (which means this is an external subqueue)
# do not initialize it
if [ -z $in_queue ]
then
    msg="INFO: Using internal input dir"
    log $msg
    init_dir $in
else
    msg="INFO: Using $in_queue out as input dir"
    log $msg
    if [ ! -d $in ]
    then
        msg="ERROR: Input dir $in does not exist. Exiting"
        log $msg
        exit 5
    fi
fi
# Is out_queue is set (which means this is an external subqueue)
# do not initialize it
if [ -z $out_queue ]
then
    msg="INFO: Using internal output dir"
    log $msg
    init_dir $out
else
    msg="INFO: Using $out_queue out as output dir"
    log $msg   
    if [ ! -d $out ]
    then
        msg="ERROR: Output dir $out does not exist. Exiting"
        log $msg
        exit 5
    fi
fi

msg="INFO: Bash Queueing script version $version .: Starting $name queue"
echo $msg
log $msg

PID=$$

if [ -f $PID_file ]
then
    echo "ERROR: The queue "$name" is already running!"
    echo "If it is not running, please remove the file "$PID_file
    echo "clean the subqueues and start it again"
    exit 3
fi

echo $PID > $PID_file
trap "rm $PID_file" EXIT

# work script validations

if [ ! -x $workscript ]
then
    echo "ERROR: $workscript does not exists, or is not executable"
    exit 6
fi

msg="INFO: Starting main loop"
echo $msg
log $msg
msg="INFO: QUEUE $name, threads $threads, deliver batch $batch, retries $retry, pooling interval $new_pooling sec"
echo $msg
log $msg
msg="INFO: Using worker script: $work"
echo $msg
log $msg

while :
do
	## locking functionality commented out
	##if get_lock $deliver_lock ; then
		##msg="Deliver queue got lock, processing"
		##echo $msg
		##log $msg
		if [ $(job_count $deliver) -eq 0 ]; then
			deliver_jobs
		fi
		##msg="Releasing deliver lock"
		##echo $msg
		##log $msg
		##unlock $deliver_lock
	##else
		##msg="Deliver queue locked, skipped"
		##echo $msg
		##log $msg
	##fi
	##if get_lock $process_lock ; then
		##msg="Process queue got lock, processing"
		##echo $msg
		##log $msg	
		process_jobs=$(job_count $process)
		if [ $process_jobs -lt $threads ] && [ $(ext_check) -eq 0 ]; then
			avail_threads=$(( $threads - $process_jobs ))
			process_job $avail_threads
		fi
		##msg="Releasing process lock"
		##echo $msg
		##log $msg
		##unlock $process_lock
	##else
		##msg="Process queue locked, skipped"
		##echo $msg
		##log $msg
	##fi
    sleep $new_pooling
	#re-read the config file: to apply configuration changes on the fly
	source ./$config_file
done

