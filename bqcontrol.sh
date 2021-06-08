#!/bin/bash
# Control queues
#
# bqcontrol.sh list stopall startall
# bqcontrol.sh start|stop config_file
# 2021 Mauricio Asenjo
# version 0.6


if [ -z $1 ]; then
	echo "usage:  for all queues: $0 list | stopall | startall
			 for a specific queue: $0 start|stop config_file
			 for help:  $0 help"
	exit 0
fi

source ./bqueue_utils.sh

#Starts the queue specified in 
# given config file
start_queue ()
{
	local queue=$1
	if [ -f $1 ]; then
		nohup ./bqueue.sh $queue &
	else
		exit 1
	fi
}

#Stops the queue by killing the pidfile
# specified in pidfile
stop_queue ()
{
	local pidfile=$1
	if [ -f $1 ]; then
		kill $(cat $pidfile)
	else
		exit 1
	fi
}

action=$1

case $action in
	
	list)
		echo "Queues in the system:"
		for i in $(find . -maxdepth 1 -name "*.conf" -type f -print)
		do
			source $i
			source ./bqueue_defs.sh
			echo $name" : "$(queue_status $name)
		done
		;;
		
	startall)
		echo "Starting all queues :"
		for i in $(find . -maxdepth 1 -name "*.conf" -type f -print)
		do
			source $i
			source ./bqueue_defs.sh
			echo "Starting "$name
			# check if queue is started or paused
			#	if [ "$($queue_status $i) 
			start_queue $i
		done
		;;
		
	stopall)
		echo "Stopping all queues :"
		for i in $(find . -maxdepth 1 -name "*.conf" -type f -print)
		do
			source $i
			source ./bqueue_defs.sh
			echo "Stopping "$name
			stop_queue $PID_file
		done
		;;
		
	*)
		echo $action": unknown option"
		exit 1
		;;
esac

