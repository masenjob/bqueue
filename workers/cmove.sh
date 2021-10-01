#!/bin/bash
# cmove
# request $source_ae to c-move
# a specified study to $dest_ae
# study can be specified by accession number or study uid
# Requires dcm4che version 5
# 2020 Mauricio Asenjo
# version 1.6

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

#defaults
query="ACC"
timeout="10m"
delay=0
verify=0

if [ -f $config ]
then
	source $config
else
	echo "ERROR: Config file "$config" not found."
	echo "Make sure the config file exists and has this format:"
	echo "calling_ae=<AET of this script>"
	echo "source_ae=<AET of the source pacs>"
	echo "source_ip=<ip of the soruce pacs>"
	echo "source_port=<port of the soruce pacs"
	echo "dest_ae=<AET of the destination pacs>"
	echo "query=<Query by (Accession number: ACC or Study UID: SUID)>"
	echo "timeout=<time to wait for cmove to complete before aborting>"
	echo "delay=<wait_seconds> # Time to wait in seconds before running the cmove"
	echo "# Optional verification only for locally stored studies"
	echo "verify=<1|0> # query the pacs for n° of instances and verify if it matches what was received"
	echo "source_dir=<path> # Where are the studies stored (needed if verify=1)"
	exit 1
fi

if [ -z $1 ]
then
	echo "ERROR: study not specified"
	exit 1
else
	study=$1
fi

srcPacsConnString=$source_ae@$source_ip:$source_port

DICOM_OK="0H"
DICOM_CONT="ff00H"

if [ "$query" = "ACC" ]; then
        queryby="-m AccessionNumber="
elif [ "$query" = "SUID" ]; then
        queryby="-m StudyInstanceUID="
fi

get-var ()
# Search for an specific result value in the output of dcm4che
# When it gets a line like this:
# 19:46:24,533 INFO  - TEST_DICOM->CUAWFMICS(1) >> 1:C-MOVE-RSP[pcid=1, completed=1, failed=0, warning=0, status=0H
# returns the value next to the = sign
# Example: if called with "status=", returns "OH"
# by splitting the string by the " " or "," character (regexp [, ])
# If several lines matches, return only de value of the last one

{
local variable=$1
echo "$result" | grep $variable | tail -1 | awk -v var="$variable" 'BEGIN {FS="[";} // { split($2, arr, "[, ]"); for (i in arr) { if(index(arr[i],var)){ gsub(var,"",arr[i]); print arr[i];} } }'
}

ERROR=0

# Open fd 6 and redirect to stdout (to capture $command output)
exec 6>&1

command="movescu -b $calling_ae -c $srcPacsConnString $queryby$study --dest $dest_ae"
if [ $delay -ne 0 ]; then
	sleep $delay
fi
echo "INFO: About to execute $command"

result="$(timeout $timeout $command | tee >(cat - >&6) | grep C-MOVE-RSP)"
exit_status=$?

if [ $exit_status -ne 0 ]
then
	echo "ERROR executing movescu, aborting"
	exit 2
fi


# Get Dicom status from cmovescu output:
status=$(get-var "status=")

if [ "$status" = "$DICOM_OK" ]
then
	msg=$study" OK dicom="$status
	# Get # of completed studies from cmovescu output:
	completed=$(get-var "completed=")
	if [ $completed -lt 1 ]; then
		ERROR=3
		echo $study" ERROR completed="$completed
		exit $ERROR
	fi
	# Get # of failed studies from cmovescu output:
	failed=$(get-var "failed=")
	if [ $failed -gt 0 ]; then
		ERROR=4
		echo $study" ERROR completed="$completed",failed="$failed
		exit $ERROR
	fi
else
	ERROR=5
	echo $study" ERROR dicom="$status
	exit $ERROR
fi

if [ $verify -eq 1 ] ; then
	nInstancesOnDisk=$(find $source_dir/$study -type f | wc -l)
	nInstancesOnPacs=$(findscu -b $calling_ae -c $srcPacsConnString -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}')
	echo "Number of instance on disk : $nInstancesOnDisk"
	echo "Number of instances on $source_ip : $nInstancesOnPacs"
	if [ $nInstancesOnDisk -lt $nInstancesOnPacs ]; then
		echo "ERROR: N° of instances in Pacs is more than what we receive"
		exit 4
	fi
fi

