#!/bin/bash
# Parse a hl7 message file to search for Image Available Notification
# and generate a job file containing the accession number
# or study uid referenced in the message
# 2021 Mauricio Asenjo
# version 0.5


# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"

#Defaults:
ACC_FIELD="OBR 18"
IAN_FIELD="ORC 25"
FILENAME="SUID"
QUERYBY="SUID"
SUID_LOCATION_FIELD="ZDS 1"
UNIQUE=0
+
if [ -f $config ]
then
        source $config
else
        echo "ERROR: Config file "$config" not found."
        echo "Make sure the config file exists and has this format:"
        echo "OUTDIR=#<directory to place .job files>"
		echo "FILENAME=#<ACC|SUID>  Use Accession Number or Study UID as filename. Default is SUID"
		echo "QUERYBY=#<ACC|SUID> Use Accession Number or Study UID as study id for query. Default is SUID"
		echo "SUID_LOCATION_FIELD=# <hl7_segment hl7_field> Segment and field of the location of the study uid in the hl7 msg. Default is \"ZDS 1\""
		echo "UNIQUE=<0|1> # Make filenames unique by adding a suffix. Default is 0"
        exit 1
fi

if [ -z "$1" ]
then
        echo "ERROR: HL7 data not found"
        exit 2
else
        HL7="$1"
fi

# Hl7 parser
# Get segment $1 , field $2 from hl7 data on $3
# Example: gen_hl7_field message.hl7 OBR 18 <hl7 data>
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
        ACC=$(get_hl7_field $ACC_FIELD "$HL7")
		# Get study uid if present
		SUID=$(get_hl7_field $SUID_LOCATION_FIELD "$HL7")
		
		# Set the job filename
		if [ "$UNIQUE" -eq 0 ] ; then
			suffix=""
		else
			suffix="_"$(date +%Y%m%d%H%M%s)
		fi
		if [ "$FILENAME" = "ACC" ] ; then
			job_file=$ACC$suffix".job"
		elif [ "$FILENAME" = "SUID" ] ; then
			job_file=$SUID$suffix".job"
		else
			echo "FILENAME option not recognized : $FILENAME"
			exit 3
		fi
		# Set the query parameter
		if [ "$QUERYBY" = "ACC" ] ; then
			query_data=$ACC
		elif [ "$QUERYBY" = "SUID" ] ; then
			query_data=$SUID
		else
			echo "QUERYBY option not recognized : $FILENAME"
			exit 4
		fi
        #Create job file
        echo $query_data > $OUTDIR/$job_file
fi
