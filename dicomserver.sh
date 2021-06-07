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
AET="TEST_DICOM"
port=11112
recv_dir=/cache/incoming
logfile=/cache/dicomserver.log
pidfile=/cache/dicomserver.pid

if [ -f $pidfile ]
then
	echo "ERROR: $0 is running, if it isn't, delete $pidfile and start again"
	exit 1
fi

echo $PID > $pidfile
trap "rm $pidfile" EXIT

#reset logfile
echo "" > $logfile

storescp -b $AET:$port --directory $recv_dir --filepath '{00080050}/{0020000D}/{0020000E}/{00080018}.dcm' >> $logfile
