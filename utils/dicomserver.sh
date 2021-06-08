#!/bin/bash
# Dicom receiver
# starts a Dicom Server on the specified port
# and stores received studies on the $dest_dir
# 
# requires dcm4che 5
#
# 2020 Mauricio Asenjo
# version 1.0

set -u

PID=$$

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
	echo "AET=<AET of the dicomserver>"
	echo "port=<port of the dicom server>"
	echo "recv_dir=<absolute path of the destination directory>"
	echo "dir_format=<format of the directories where the study is stored"
	echo "#example: dir_format='{00080050}/{0020000D}/{0020000E}/{00080018}.dcm'"
	exit 1
fi

logfile=$dir"/"$(basename $0)".log"
pidfile$dir"/"$(basename $0)".pid"

if [ -f $pidfile ]
then
	echo "ERROR: $0 is running, if it isn't, delete $pidfile and start again"
	exit 1
fi

echo $PID > $pidfile
trap "rm $pidfile" EXIT

#reset logfile
echo "" > $logfile

storescp -b $AET:$port --directory $recv_dir --filepath $dir_format >> $logfile
