#!/bin/bash
#
# dicomsender.sh
# sends a study specified by command line
# to the pacs referenced in the config file
# Source study path is composed of the
# $sourcedir variable / command line parameter
# Requires dcm4che version 5 in the path
#
# 2021 Mauricio Asenjo
# version 2

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
	echo "dest_ae=<AET of the destination pacs>"
	echo "dest_host=<IP of the destination pacs>"
	echo "dest_port=<port of the detination pacs>"
	echo "source_dir=<absolute path of the source studies>"
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

#Path to the storescu utility of dcm4che:
storescu=storescu

DICOM_OK="0H"
DICOM_CONT="ff00H"

get-var ()
# Search for an specific result value in the output of dcm4che
# When it gets a line like this:
# 19:46:24,533 INFO  - TEST_DICOM->CUAWFMICS(1) >> 1:C-MOVE-RSP[pcid=1, completed=1, failed=0, warning=0, status=0H
# returns the value next to the = sign
# Example: if called with "status=", returns "OH"
# by splitting the string by the " " or "," character (regexp [, ])

{
local variable=$1
echo $result | awk -v var="$variable" 'BEGIN {FS="[";} // { split($2, arr, "[, ]"); for (i in arr) { if(index(arr[i],var)){ gsub(var,"",arr[i]); print arr[i];} } }'
}

# Open fd 6 and redirect to stdout (to capture $command output)
exec 6>&1

command="storescu -b $calling_ae -c $dest_ae@$dest_host:$dest_port $source_dir/$study"
echo "INFO: About to execute $command"

rsp_count=0
timeout $timeout $command | tee >(cat - >&6) | grep C-STORE-RSP | \
while read -r line
do
	$status=$(get-var "status=")
	$rsp_count=$(( $rsp_count + 1 ))
	if [ "$status" != "$DICOM_OK" ]
		msg=$study" ERROR: status="$status
		echo $msg
		exit 1
	fi
done
# Exit if last command was not succesful
exit_status=$?
if [ $exit_status -ne 0 ]
then
	echo "ERROR executing $storescu, aborting"
	exit 2
fi

# Exit if we got 0 lines containing C-STORE-RSP
if [ $rsp_count -eq 0 ]
then
	msg=$study" ERROR: 0 instances sent"
	echo $msg
	exit 3
fi

echo "INFO: Deleting study $study after successful transfer"
rm -rf $source_dir/$study
