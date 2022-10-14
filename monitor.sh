#!/bin/bash
# BASH QUEUE MONITOR
#
# Displays status info of all queues
#
# 2022 Mauricio Asenjo
# version 2.1rc1

source ./bqueue_utils.sh

case "$OSTYPE" in
linux*)
	cpu_model=$(cat /proc/cpuinfo | grep -m 1 "model name")
	cpu_count = $(cat /proc/cpuinfo | grep -c "model name")
	;;

freebsd*)
	cpu_model=$(sysctl -n hw.model)
	cpu_count=$(sysctl -n hw.ncpu)
	;;
	
*)
	cpu_model="NOT_SUPPORTED"
	cpu_count="N/A"
	;;
esac


format="%-15s %-10s %-10s %-10s %-10s %-10s %-10s\n"
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
	echo "CPU $cpu_model , count = $cpu_count"

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