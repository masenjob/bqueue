#!/bin/bash
set -u

#Archive source dir:
source=/centera/archive

#Archive destination dir:
dest=/unitynas/archive

if [ -z $1 ]
then
        echo "USAGE: $0 <archive_dir>"
        exit 1
fi

dir=$1

# echo "INFO: About to execute rsync -av $source/$dir $dest/"
rsync -av $source/$dir $dest/ 2>&1 | (cat - )
