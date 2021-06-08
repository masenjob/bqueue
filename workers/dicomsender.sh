#!/bin/bash
#
# dicomsender.sh
# sends a study specified by command line
# to the pacs referenced in the config file
# Source study path is composed of the
# $sourcedir variable / command line parameter
# Requires dcm4che version 5 in the path
#
# 2020 Mauricio Asenjo
# version 1.1

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


if [ -z $1 ]
then
	echo "ERROR: study not specified"
	exit 1
else
	study=$1
fi

command="storescu -b $calling_ae -c $dest_ae@$dest_host:$dest_port $source_dir/$study"

echo "INFO: About to execute $command"

timeout $timeout $command
status=$?

if [ $status -ne 0 ]; then
	echo "ERROR: Failed to send study $study to $dest_ae@$dest_host"
	exit 1
fi
echo "INFO: Deleting study $study after successful transfer"
rm -rf $source_dir/$study
