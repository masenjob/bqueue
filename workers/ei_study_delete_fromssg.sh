#!/bin/bash
#
# Executes a call to EI restfull API
# DELETE v1/study/fromSSG
# to delete study objets and db references to them
# from specified SSG, only if there are copies on other locations

# 2022 Mauricio Asenjo
# version 0.13

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


req_type="DELETE"
req_url="https://$ei_fqdn"
req_path="/pacs/v1/study/fromSSG"
req_query_name[0]="studyUid"
req_query_value[0]="$study"
req_query_name[1]="storageGroupName"
req_query_value[1]="$(urlEncode "$SSGName")"
req_query_name[2]="deleteFiles"
req_query_value[2]="true"

request_uri="$req_url$req_path"

separator="?"
for i in ${!req_query_name[@]}
do
	request_uri="$request_uri$separator${req_query_name[$i]}=${req_query_value[$i]}"
	separator="&"
done

echo "INFO : about to execute request: $request_uri"

curl -k -s -f -X $req_type \
--header 'Accept: application/json' \
--header "Authorization: Bearer $token" \
$request_uri \
-w 'http_status: %{http_code}\n' | tail -1
