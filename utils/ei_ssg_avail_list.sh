#!/bin/bash
# from a list of study UIDS , prints the ssg availability
# of each study
# 2022 Mauricio Asenjo 
# version 0.14

# TODO: Get the list of SSG from EI via restful API

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

if [ -f $config ]
then
    source $config
else
	echo "config file not found"
	echo "Make sure there is a $config file and has this contents:"
	echo "ssg_name[0]=\"\" # Name of the SSG 0 (in quotes)"
	echo "ssg_name[1]=\"\" # Name of the SSG 1 (in quotes)"
	echo "getStudyLocation= # name and full path of the getStudyLocation script"
fi

# Get study locations script
getStudyLocation="/cache/bqueue-dev/workers/ei_get_study_location.sh"

if [ -z "$1" ]
then
        echo "ERROR: study list file not specified"
        exit 1
else
        studylist="$1"
fi

if ! [ -f "$studylist" ]
then
        echo "ERROR: $studylist not found"
        exit 2
fi

# From a json read from stdin
# gets the avaiability of the specified
# ssg 
ssgAvail () {
	local ssgName="$1"
	read -s json
	if ! (echo $json | jq -e . > /dev/null 2>&1); then
		echo "ERROR"
	else
		    full="$(echo $json | ssgName="$ssgName" jq -re '.fullAvailability[] | select(.name == env.ssgName ) | .name')"
		 partial="$(echo $json | ssgName="$ssgName" jq -re '.partialAvailability[] | select(.name == env.ssgName ) | .name')"
		viewable="$(echo $json | ssgName="$ssgName" jq -re '.viewableAvailability[] | select(.name == env.ssgName ) | .name')"
		if [ "$full" = "$ssgName" ] 
		then
			echo "FULL"
		elif  [ "$partial" = "$ssgName" ]
		then
			echo "PARTIAL"
		elif [ "$viewable" = "$ssgName" ]
		then 
			echo "VIEWABLE"
		else
			echo "NO"
		fi
	fi
}

format="%-64s"
header="STUDY_UID"
for i in "${ssg_name[@]}"
do
	i=$( echo $i | sed 's/ //g' ) # trim white spaces
	format=$format" %-"${#i}"s"
	header=$header" "$i
done
format=$format"\n"

printf "$format" $header

while read -r line
do
	output=$line
	for i in "${ssg_name[@]}"
	do
		json=$($getStudyLocation $line)
		output=$output" "$(echo "$json" | ssgAvail "$i")
	done
	printf "$format" $output
done < "$studylist"
