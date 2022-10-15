#!/bin/bash
# rsync a specified subpath
# between $SOURCE and $DEST directories
# 2022 Mauricio Asenjo
# version 0.3

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

# defaults
delay=1

if [ -f $config ]
then
        source $config
else
	echo "config file not found"
	echo "Make sure there is a $config file and has this contents:"
	echo "SOURCE= #source directory"
	echo "DEST= #destination directory"
fi

if [ -z $1 ]
then
        echo "ERROR: sub-path not specified"
        exit 1
fi

DIR=$1

# Create destination directory if required:
mkdir -p $DEST/$DIR/

echo "INFO: About to execute rsync -avi --checksum --dry-run $SOURCE/$DIR/ $DEST/$DIR/  2>&1 | (cat - )"
rsync -rvi --checksum $SOURCE/$DIR/ $DEST/$DIR/  2>&1 | (cat - )