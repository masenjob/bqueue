#!/bin/bash
#
# dicomsender2.sh
# sends a study by studdy_uid specified by command line
# using dicom over ssl if specified
# to the pacs referenced in the config file
# Source study path is composed of the
# $sourcedir variable / command line parameter
# studies are required to be stored in the structure:
#  study_uid/series_uid
# Requires dcm4che version 5 in the path
#
# 2021 Mauricio Asenjo
# version 2.4

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
		echo "verify=<1|0> # query the pacs for n° of instances and verify if it matches what was received. This enables sending ONLY the series not present in destination"
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
{
	# Search for an specific result value in the output of dcm4che
	# When it gets a line like this:
	# 19:46:24,533 INFO  - TEST_DICOM->CUAWFMICS(1) >> 1:C-MOVE-RSP[pcid=1, completed=1, failed=0, warning=0, status=0H
	# returns the value next to the = sign
	# Example: if called with "status=", returns "OH"
	# by splitting the string by the " " or "," character (regexp [, ])
	local variable="$1"
	echo "$result" | grep $variable | awk -v var="$variable" 'BEGIN {FS="[";} // { split($2, arr, "[, ]"); for (i in arr) { if(index(arr[i],var)){ gsub(var,"",arr[i]); print arr[i];} } }'
}

get_series_from_disk ()
{
	# Outputs a list of series from study stored on disk
	# in the given path, assuming it was stored with the dir
	# structure: /studies/study_uid/series_uid/
	
	# (tail removes the firat line, has it always contains the parent dir)
	local series="$(find $source_dir/$study -maxdepth 1 -type d  -printf "%f\n" | tail -n +2 | sort -u)"
	if [ ! -z "$series" ] ; then
		echo "$series"
		return 0
	else
		return 1
	fi
}

get_series_from_pacs ()
{
	# Outputs a list of series from study 
	# queries to pacs specified in given
	# connection string
	# ($ssl_opts must be defined globally if needed)
	local calling_ae=$1
	local pacsConnString=$2
	local series="$(findscu -b $calling_ae -c $pacsConnString $ssl_opts -L SERIES -m StudyInstanceUID=$study -r SeriesInstanceUID |  grep 0020,000E | awk -F'[\\[\\]]' '{print $2}' | grep "\S" | sort -u)"
	if [ ! -z "$series" ] ; then
		echo "$series"
		return 0
	else
		return 1
	fi
}

send_to_pacs ()
{
	# Send dicom objects stored in the specified
	# path to the pacs specified in the given
	# connection string
	# ($ssl_opts must be defined globally if needed)
	local calling_ae=$1
	local pacsConnString=$2
	local objects_path="$3"
	local error=0
	exec 5>&1
	local dcmout="$(storescu -b $calling_ae -c $pacsConnString $ssl_opts $objects_path | tee >(cat - >&5) )"
	error=$?
	exec 5<&-
	# detect if there was an EOF exception:
	if ( echo $dcmout | grep -q -i "EOFexception" ); then
		error=1
	fi
	local rsp_count=0

	while read -r result
	do
        status=$(get-var "status=")
		if [[ ! -z "$status" ]] ; then
			if [ "$status" = "$DICOM_OK" ] ; then
				rsp_count=$((rsp_count+1))
			else
                error=2
			fi
		fi
	done <<< $(echo "$dcmout" | grep C-STORE-RSP)
	
	# Declare error if we got 0 lines containing C-STORE-RSP
	if [ "$rsp_count" -eq 0 ] ; then
        error=3
	fi
	return $error
}

if [ ! -d "$source_dir/$study" ]; then
	echo "ERROR: Study $source_dir/$study not found. Exiting"
	exit 1
fi

diskSeries="$(get_series_from_disk)"

if [ $verify -eq 1 ] ; then
	# Only transmit series not in pacs
	pacsSeries="$(get_series_from_pacs $calling_ae $pacsConnString)"
	#compare source series with dest series
	seriesToSend="$(comm -23 <(echo "$diskSeries") <(echo "$pacsSeries") | grep "\S" )"
else
	# Transmit everything in source study
	seriesToSend=$diskSeries
fi

# Transmit series
error=0
if [ -z $seriesToSend ] ; then
	echo "WARNING: Nothing to send for study $study"
else
	tries=2
	for serie in $seriesToSend
	do
		echo "INFO: Starting transmission of study: $study , series : $serie"
		try=0
		sent=0
		while [ $try -lt $tries ]
		do
			if (send_to_pacs $calling_ae $pacsConnString $source_dir/$study/$serie); then
				echo "iNFO: transmission successful for series : $serie , try $try"
				try=$tries
				sent=1
			else
				echo "INFO: transmission problem for series : $serie , try $try"
				((try++))
			fi
		done
		if [ "$sent" -eq 0 ]; then
			echo "ERROR: problems transmitting series : $serie"
				error=1
		fi
	done
fi

if [ "$error" -neq 0 ] ; then
	exit $error
fi

if [ $verify -eq 1 ] ; then
	# Get study series in dest Pacs:
	pacsSeries="$(get_series_from_pacs $calling_ae $pacsConnString)"

	#compare source series with dest series
	seriesDiff="$(comm -23 <(echo "$diskSeries") <(echo "$pacsSeries") | grep "\S" )"

	if [ -z "$seriesDiff" ]; then
		echo "INFO: VERIFY  $study instances on $source_host ok"
		error=0
	else
		echo "ERROR: VERIFY $study instances on $source_host missing in $dest_host : $seriesDiff"
		error=2
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
