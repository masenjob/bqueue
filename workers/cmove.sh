#!/bin/bash
# cmove
# request $source_ae to c-move
# a specified study to $dest_ae
# study can be specified by accession number or study uid
# Requires dcm4che version 5
# 2020 Mauricio Asenjo
# version 1.2

#### CONFIGURATION ####
#AE of the local movescu (source pacs must be configured to accept assoc from this AE)
calling_ae=TEST_DICOM
# Source PACS (where we will cmove from)
source_ae=IMPAXUCSC
source_ip=192.168.105.11
source_port=104
#Destination PACS (where we will cmove to)
dest_ae=TEST_DICOM
# Query by (Accession number: "ACC" , Study UID: "SUID")
query="ACC"
### END OF CONFIGURATION ###

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

{
local variable=$1
echo $result | awk -v var="$variable" 'BEGIN {FS="[";} // { split($2, arr, "[, ]"); for (i in arr) { if(index(arr[i],var)){ gsub(var,"",arr[i]); print arr[i];} } }'
}

ERROR=0

# Open fd 6 and redirect to stdout (to capture $command output)
exec 6>&1

command="$movescu -b $calling_ae -c $source_ae@$source_ip:$source_port $queryby$study --dest $dest_ae"
echo "INFO: About to execute $command"

result=$($command | tee >(cat - >&6) | grep -v remaining | grep C-MOVE-RSP)
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
