#!/bin/bash
#
# Executes a call to EI restfull API
# GET v1/study/getStudyLocation
# Returns the the json with full and partial locations for a study given
# either a study UID or an accession number as the identifier

# 2022 Mauricio Asenjo
# version 0.3

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

# Outputs given sinlge line string in URL encoded format using jq
urlEncode () {
	echo "$1" |  jq -rR @uri
}

# defaults

timeout="10m"
tempdir="/tmp"

if [ -f $config ]
then
        source $config
else
	echo "config file not found"
	echo "Make sure there is a $config file and has this contents:"
	echo "SSGName=\"\" # Name of the SSG (in quotes)"
	echo "ei_fqdn= # FQDN of Enterprise Imaging"
	echo "token_file= # Full path of the token file"
fi

if [ -z $1 ]
then
        echo "ERROR: study not specified"
        exit 1
else
        study=$1
fi

# Get the token from the token file
if [ -f "$token_file" ] ; then
	token=$(cat "$token_file")
else
	echo "ERROR: Cannot read token from $token_file"
	exit 2
fi


req_type="GET"
req_url="https://$ei_fqdn"
req_path="/pacs/v1/study/getStudyLocation"
req_query_name[0]="studyUid"
req_query_value[0]="$study"

request_uri="$req_url$req_path"

separator="?"
for i in ${!req_query_name[@]}
do
	request_uri="$request_uri$separator${req_query_name[$i]}=${req_query_value[$i]}"
	separator="&"
done

# echo "INFO : about to execute request: $request_uri"

curl -k -s -f -X $req_type \
--header 'Accept: application/json' \
--header "Authorization: Bearer $token" \
$request_uri