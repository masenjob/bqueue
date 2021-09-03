#!/bin/bash
# cmove
# request $source_ae to c-move
# a specified study to $dest_ae
# study can be specified by accession number or study uid
# Requires dcm4che version 5
# 2020 Mauricio Asenjo
# version 1.4

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

if [ -f $config ]
then
	source $config
else
	echo "ERROR: Config file "$config" not found."
	echo "Make sure the config file exists and has this format:"
	echo "calling_ae=<AET of this script>"
	echo "source_ae=<AET of the source pacs>"
	echo "source_ip=<ip of the source pacs>"
	echo "source_port=<port of the source pacs"
	echo "dest_ae=<AET of the destination pacs>"
	echo "query=<Query by (Accession number: ACC or Study UID: SUID)>"
	echo "timeout=<time to wait for cmove to complete before aborting>"
	exit 1
fi

if [ -z $1 ]
then
	echo "ERROR: study not specified"
	exit 1
else
	study=$1
fi

#Path to the movescu utility of dcm4che:
movescu=movescu

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

command="$movescu -b $calling_ae -c $source_ae@$source_ip:$source_port $queryby$study --dest $dest_ae"
echo "INFO: About to execute $command"

result="$(timeout $timeout $command | tee >(cat - >&6) | grep C-MOVE-RSP)"
exit_status=$?

if [ $exit_status -ne 0 ]
then
	echo "ERROR executing $movescu, aborting"
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
		ERROR=1
		msg=$study" ERROR completed="$completed
	fi
	# Get # of failed studies from cmovescu output:
	failed=$(get-var "failed=")
	if [ $failed -gt 0 ]; then
		ERROR=1
		msg=$study" ERROR completed="$completed",failed="$failed
	fi
else
	ERROR=1
	msg=$study" ERROR dicom="$status
fi
echo $msg
exit $ERROR
