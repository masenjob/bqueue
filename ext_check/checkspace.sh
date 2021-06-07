#!/bin/bash
#
# checkspace.sh
#
# Checks is the usage percentage of the configured
# volume reaches the configured limit
# returns exit status 0 if limit has not been reached

## CONFIGURATION ##
# Path of the mounted volume to checkspace
volume="/cache"

# space limit (usage percentage)
limit=90

## END OF CONFIGURATION ##

command="df --output=pcent,target"

percent=$($command | grep $volume | awk '{print substr($1, 1, length($1)-1)}')

if [ $percent -gt $limit ] ; then
	#echo "Limit of $limit % has been reached"
	exit 1
fi
