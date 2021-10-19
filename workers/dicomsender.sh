#!/bin/bash
#
# dicomsender.sh
# sends a study specified by command line
# using dicom over ssl if specified
# to the pacs referenced in the config file
# Source study path is composed of the
# $sourcedir variable / command line parameter
# Requires dcm4che version 5 in the path
#
# 2021 Mauricio Asenjo
# version 2.2

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

# defaults
ssl="FALSE"
timeout="10m"
verify=0
delete=1

if [ -f $config ]
then
        source $config
else
        echo "ERROR: Config file $config not found."
        echo "Make sure the config file exists and has this format:"
        echo "calling_ae=<AET> #AET of this sender"
        echo "dest_ae=<AET> #AET of the destination pacs"
        echo "dest_host=<IP> #IP of the destination pacs"
        echo "dest_port=<port> #Port of the detination pacs"
        echo "source_dir=<path> #Absolute path of the location of the studies"
        echo "timeout=<time> #Time to wait for cstore to complete before aborting. Defaul: 10m"
		echo "ssl=<TRUE/FALSE> # Use ssl (default FALSE)"
		echo "trustore=<path> # Full path of the trustore file"
		echo "trustpass=<password> #Password of the keystore file"
		echo "verify=<1|0> # query the pacs for n° of instances and verify if it matches what was received"
		echo "delete=<1|0> # delete study after successful transfer"
        exit 1
fi

if [ -z $1 ]
then
        echo "ERROR: study not specified"
        exit 1
else
        study=$1
fi

if [ "$ssl" = "TRUE" ] ; then
	ssl_opts="--trust-store $trustore  --trust-store-pass $trustpass --tls1 --tls-aes"
fi

pacsConnString=$dest_ae@$dest_host:$dest_port
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
local variable="$1"
echo "$result" | grep $variable | awk -v var="$variable" 'BEGIN {FS="[";} // { split($2, arr, "[, ]"); for (i in arr) { if(index(arr[i],var)){ gsub(var,"",arr[i]); print arr[i];} } }'
}

# Open fd 6 and redirect to stdout (to capture $command output)
exec 6>&1

command="storescu -b $calling_ae -c $dest_ae@$dest_host:$dest_port $ssl_opts $source_dir/$study"
echo "INFO: About to execute $command"

error=0
rsp_count=0
#timeout $timeout $command | tee >(cat - >&6) | grep C-STORE-RSP | \
while read -r result
do
        status=$(get-var "status=")
		if [[ ! -z "$status" ]] ; then
			if [ "$status" = "$DICOM_OK" ] ; then
				rsp_count=$((rsp_count+1))
			else
				# if any instance is not DICOM_OK, declare failure
                msg=$study" ERROR: status="$status
                echo $msg
                error=1
			fi
		fi
done <<< $(timeout $timeout $command | tee >(cat - >&6) | grep C-STORE-RSP )

# Declare error if we got 0 lines containing C-STORE-RSP
if [ "$rsp_count" -eq 0 ]
then
        echo $study" ERROR: $rsp_count instances sent"
        exit 3
fi
if [ $verify -eq 1 ] ; then
	nInstancesOnDisk=$(find $source_dir/$study -type f | wc -l)
	# delay verification to allow Pacs to register objects
	sleep 60 
	queryCommand="findscu -b $calling_ae -c $pacsConnString $ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}'"
	echo "About to execute: $queryCommand"
	nInstancesOnPacs=$(findscu -b $calling_ae -c $pacsConnString $ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}')
	echo "Number of instance on disk : $nInstancesOnDisk"
	echo "Number of instances on $dest_host : $nInstancesOnPacs"
	if [ $nInstancesOnDisk -gt $nInstancesOnPacs ]; then
		echo "ERROR: N° of instances in Pacs is less than what we sent"
		exit 4
	fi
fi

if [ "$error" -eq 0 ]; then
	if [ $delete -eq 1 ] ; then
		echo "INFO: Deleting study $study after successful transfer"
		rm -rf $source_dir/$study
	fi
else
	echo " ERROR $error"
	exit $error
fi