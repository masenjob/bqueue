#!/bin/bash
# EI token service
# Request periodicaly a new auth token
# for use by EI restful api scripts
# 2022 Mauricio Asenjo
# requires jq in the path
# version 0.6

# check if jq is present
if jq --version ; then
	echo "$(date) INFO: jq found"
else
	echo "$(date) ERROR: , exiting"
	exit 1
fi

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"
pidfile=$dir"/"$(basename $0)".pid"

if [ -f $config ]
then
        source $config
else
        echo "ERROR: Config file "$config" not found."
        echo "Make sure the config file exists and has this format:"
        echo "ei_fqdn= # FQDN of Enterprise Imaging"
		echo "ei_user= # Enterprise Iamging user name"
		echo "ei_password= # Enterprise Iamging passwprd"
		echo "ei_domain=internal # EI Authenticatrion Domain (Internal,LDAP1,LDAP2, etc.)"
		echo "token_file= # Full path and filename to store the token"
        exit 2
fi

# Obtains a new auth token json from Enterprise Imaging 8.1.4
get_json_token (){
	local token_url="https://"$ei_fqdn"/auth/realms/EI/protocol/openid-connect/token?targetIdp=$ei_domain"
	local token=$(curl -k -s -L -X POST "$token_url" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -b tempCookiefile \
     -d "username=$ei_user" \
     -d "password=$ei_password" \
     -d "grant_type=password" \
     -d "client_id=netboot") 
	if [ -z "$token" ]; then
        return 1
    else
	    echo $token
        return 0
    fi
}

if [ -f "$pidfile" ] ; then
	echo "ERROR: Pid file $pidfile found: exiting"
	echo "If $(basename $0) is not running, delete the file with rm -f $pidfile and start again"
	exit 1
fi

trap "rm -f $pidfile" EXIT

while json_token=$(get_json_token)
do
	echo "$(date) INFO: Writing new token in $token_file"
	echo $json_token | jq -r .access_token > $token_file
	token_exp=$(echo $json_token | jq -r .expires_in)
	echo "$(date) INFO: Sleeping for $(( $token_exp - 2 )) secs."
	sleep $(( $token_exp - 2 ))
done
