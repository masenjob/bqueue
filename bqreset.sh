#!/bin/bash
# Reset specific queue status
# bqreset.sh config_file action
# 2021 Mauricio Asenjo
# version 0.5

# first argument
if [ -z $1 ]; then
	echo "usage:  $0 <queue_config_file> logs|queues|all"
	exit 0
else
	queue_conf=$1
fi

source ./bqueue_utils.sh

if [ -f $queue_conf ]; then
	source $queue_conf
	source ./bqueue_defs.sh
else
	echo "Config file not found: "$queue_conf
	exit 1
fi

if [ -z $2 ]; then
	echo "missing option : logs|queues|all"
	exit 2
else
	action=$2
fi



reset_logs ()
{
	# Clear queue logfile
	echo "" > $logdir/$logfile
	# Clear queue process log
	echo "" > $logdir/$logprocfile
}

reset_all_queues ()
{
for i in $in $deliver $process $failed $finished $out ;
do
	# delete with find, as rm will fail if there are too many files
	# ( see : getconf ARG_MAX)
	echo "emptying "$i
	find $i -maxdepth 1 -type f -name '*' -delete
done
}


case $action in
	
	logs)
		echo "Resetting logs"
		reset_logs
		;;
		
	queues)
		echo "Deleting all queue messages"
		reset_all_queues
		;;
		
	all)
		echo "Resetting queue"
		reset_logs
		reset_all_queues
		;;
		
	*)
		echo $action": unknown option"
		exit 1
		;;
esac