#!/bin/bash
#
# dicomsender.sh
# sends a study specified by command line
# to the pacs referencied in this script
# Source study path is composed of the
# $sourcedir variable / command line parameter
# Requires dcm4che version 5 in the path
#
# 2020 Mauricio Asenjo
# version 1.0


#### CONFIGURATION ####

#AE of the local store scu (destination pacs must be configured to accept assoc from this AE)
calling_ae=TEST_DICOM
# Destination PACS (where we will cmove to)
dest_ae=WFMGR
dest_host=192.168.160.132
dest_port=9104
#Destination PACS (where we will cmove to)
dest_ae=TEST_DICOM
# Directory where studies are stored
source_dir="/cache/transformed"

### END OF CONFIGURATION ###

if [ -z $1 ]
then
	echo "ERROR: study not specified"
	exit 1
else
	study=$1
fi

command="storescu -b $calling_ae -c $dest_ae@$dest_host:$dest_port $source_dir/$study"

echo "INFO: About to execute $command"

$command
status=$?

if [ $status -ne 0 ]; then
	echo "ERROR: Failed to send study $study to $dest_ae@$dest_host"
	exit 1
fi
echo "INFO: Deleting study $study after successful transfer"
rm -rf $source_dir/$study
