#!/bin/bash

# Test a connection and return the http status

url=$1
status=$(curl -k -i $url | grep HTTP | awk '{ print $2 }')
echo $status
if [ "$status" -eq 200 ] ; then
	exit 0
fi
exit 1
