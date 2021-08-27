#!/bin/bash
# Parse a hl7 message file to search for Image Available Notification
# and generate a job file containing the accession number
# referenced in the message
# 2021 Mauricio Asenjo
# version 0.2


# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

if [ -f $config ]
then
        source $config
else
        echo "ERROR: Config file "$config" not found."
        echo "Make sure the config file exists and has this format:"
        echo "OUTDIR=<directory to place .job files>"
        exit 1
fi

if [ -z "$1" ]
then
        echo "ERROR: HL7 data not found"
        exit 1
else
        HL7="$1"
fi

# Hl7 parser
# Get segment $2 , field $3 from file $1
# Example: gen_hl7_field message.hl7 OBR 18
get_hl7_field ()
{
local HL7SEG=$1
local HL7FIELD=$2
local HL7="$3"
echo "$HL7" | awk -v seg=$HL7SEG -v field=$HL7FIELD 'BEGIN{ RS = "\r" ; FS = "|" }{ if ( $1 == seg ) print $(field+1) ; }'
}

#check if ORC 25 = IMAGES_AVAILABLE
if [ "$(get_hl7_field ORC 25 "$HL7")" = "IMAGES_AVAILABLE" ]
then
        # Get accession number
        ACC=$(get_hl7_field OBR 18 "$HL7")
        #Create job file
        echo $ACC > $OUTDIR/$ACC".job"
fi

