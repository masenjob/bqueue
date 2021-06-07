#!/bin/bash
#
# monitor_queue.sh
#
# Prits the status of subqueues on screen for the specified queue
# referenced on its config file
# takes the queue config file as a parameter
# 2020 Mauricio Asenjo
# version 1.1

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

PID=$$

source ./$config_file

# Is in_queue is set, set the "out" dir of the specified queue as "in"
# otherwise, set it to the internal default
if [ -z $in_queue ]
then
    in=$name"/in"
    init_dir $in    
else
    in=$in_queue"/out"
    if [ ! -d $in ]
    then
        exit 5
    fi
fi

# Count jobs (files) in a queue, takes queue_name as argument
job_count ()
{
    local subqueue=$1
    local count=$(find $subqueue -maxdepth 1 -type f -name '*.job' -print | wc -l)
    echo $count
}

overwrite() { echo -e "\r\033[1A\033[0K$@"; }

while true 
do
	overwrite "Time:$(date +%H:%M:%S), in: $(job_count $in) , deliver: $(job_count $name/deliver) , processing: $(job_count $name/process) , finished: $(job_count $name/finished) , failed: $(job_count $name/failed)"
	sleep 1
done