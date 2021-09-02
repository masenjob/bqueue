#!/bin/bash

# Test a connection and return the http status

url=$1
status=$(curl -i $url | grep HTTP | awk '{ print $2 }')
echo $status
