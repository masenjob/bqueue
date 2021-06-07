#!/bin/bash
# BASH QUEUE MONITOR
#
# Displays status info of all queues
#
# 2020 Mauricio Asenjo
# version 2.0rc4

source ./bqueue_utils.sh

format="%-15s %-10s %-10s %-10s %-10s %-10s %-10s"
string="QUEUE STATE IN DELIVER PROCESSING FINISHED FAILED"

while true
do
	clear
	line=0
	tput cup $line 0
	echo "BASH QUEUE MONITOR"
	
	line=$(($line + 1))
	tput cup $line 0
	uptime
	line=$(($line + 1))
	tput cup $line 0
	echo "CPU $(cat /proc/cpuinfo | grep -m 1 "model name") , count = $(cat /proc/cpuinfo | grep -c "model name")"

	line=$(($line + 2))
	tput cup $line 0
	printf "$format" $string

	line=$(($line + 2))
	for i in $(find . -maxdepth 1 -name "*.conf" -type f -print)
	do
		source $i
		source ./bqueue_defs.sh
		tput cup $line 0
		printf "$format" $name $(queue_status $name) $(job_count $in) $(job_count $deliver)/$batch $(job_count $process)/$threads $(job_count $finished) $(job_count $failed)
		line=$(($line + 1))
	done
	sleep 5
done