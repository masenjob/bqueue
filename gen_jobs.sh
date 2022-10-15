#!/bin/bash
#
# gen_jobs.sh
#
# Generates job files using the specified text file as input
# and populates with them the "in" directory of the queue 
# specified by its config file
#
# 2022 Mauricio Asenjo
# version 1.3

unique=0
while getopts c:i:u option
do
case "${option}"
in
c) config_file=${OPTARG};;
i) input_file=${OPTARG};;
u) unique=1;;
esac
done

echo "$0 : Generates jobs to the specified queue from an input file"

if [ -z $config_file ] || [ -z $input_file ]
then
	echo "USAGE: $0 -c <queue_config_file> -i <input_file> "
	echo "for random (unique) filenames (instead of the contents of the file):"
	echo  "$0 -c <queue_config_file> -i <input_file> -u"
	exit 1
fi

for j in $config_file $input_file
do
	if [ ! -f $j ]
	then
		echo "$j : file not found. Exiting"
		exit 2
	fi
done

source ./$config_file

export name

echo " Using input file $input_file to populate dir $name/in"

count=0

while read -r line
do
	if [ "$unique" -eq 1 ] ; then
		echo $line > $name/"in"/$(date +%d%m%Y%M%S)"-"$count".job"
	else
		echo $line > $name/"in"/$line".job"
	fi
	count=$(( $count + 1 ))
done < $input_file
echo "$count jobs created"
exit 0