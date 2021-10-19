#!/bin/bash
#
# dicom_verify_series.sh
# verify that a study specified in
# command line has all of it series in source pacs
# present in destination pacs 
#
# 2021 Mauricio Asenjo
# version 0.2

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"


# defaults
source_ssl="FALSE"
dest_ssl="FALSE"
timeout="10m"
tempdir="/tmp"

if [ -f $config ]
then
        source $config
else
	echo "config file not found"
	echo "Make sure there is a $config file and has this contents:"
	echo "#source pacs options"
	echo "source_aet=<AET> # Source pacs AETITLE"
	echo "source_host=<hostname_or_ip> # Source pacs hostname or ip address"
	echo "source_port=<port> # source pacs dicom port"
	echo "# Optional source ssl options"
	echo "#source_ssl=<TRUE|FALSE>"
	echo "#source_trustore=/root/certs/falpKeystore.pkcs12"
	echo "#source_trustpass=4gf42w1n"
	echo "#destination pacs options"
	echo "dest_aet=<AET> # Destination pacs AETITLE"
	echo "dest_host=<hostname_or_ip> # Destination pacs hostname or ip address"
	echo "dest_port=<port> # Destination pacs AETITLE"
	echo "# Optional destination ssl options"
	echo "# dest_ssl=TRUE"
	echo "# dest_trustore=/root/certs/falpKeystore.pkcs12"
	echo "# dest_trustpass=4gf42w1n"
	echo "calling_ae=<AET> # AET for query"
	echo "timeout=<10m> # timeout in minutes"
	echo "study_id=<ACC|SUID> # Study query parameter is Accession number ACC or StudyUID SUID"
	echo "tempdir=<dir> # Directory to store temp files (default /tmp" 
fi

if [ -z $1 ]
then
        echo "ERROR: study not specified"
        exit 1
else
        study=$1
fi

if [ "$source_ssl" = "TRUE" ] ; then
	source_ssl_opts="--trust-store $source_trustore  --trust-store-pass $source_trustpass --tls1 --tls-aes"
fi

if [ "$dest_ssl" = "TRUE" ] ; then
	dest_ssl_opts="--trust-store $dest_trustore  --trust-store-pass $dest_trustpass --tls1 --tls-aes"
fi

sourcePacsConnString=$source_aet@$source_host:$source_port
destPacsConnString=$dest_aet@$dest_host:$dest_port
sourceSeriesFile="$tempdir"/$study"_source_series.txt"
destSeriesFile="$tempdir"/$study"_dest_series.txt"

trap "command rm $sourceSeriesFile $destSeriesFile" EXIT

# Returns 0 if a value is an integer, 1 otherwise
isdecimal() {
  # filter octal/hex/ord()
  num=$(printf '%s' "$1" | sed "s/^0*\([1-9]\)/\1/; s/'/^/")
  test "$num" && printf '%f' "$num" >/dev/null 2>&1
}

# Get study series in source Pacs:

echo "About to execute: findscu -b $calling_ae -c $sourcePacsConnString $source_ssl_opts -L SERIES -m StudyInstanceUID=$study -r SeriesInstanceUID | grep 0020,000E | awk -F'[\\[\\]]' '{print $2}' | grep "\S" | sort -u  "

findscu -b $calling_ae -c $sourcePacsConnString $source_ssl_opts -L SERIES -m StudyInstanceUID=$study -r SeriesInstanceUID | grep 0020,000E | awk -F'[\\[\\]]' '{print $2}' | grep "\S" | sort -u >$sourceSeriesFile

nSeriesOnSourcePacs=$(cat $sourceSeriesFile | wc -l || echo 0)

if [ "$nSeriesOnSourcePacs" -gt 0 ] ; then
	echo "INFO: Number of series on $source_host : $nSeriesOnSourcePacs"
else
	echo "ERROR: Problem getting series list on $source_host"
	exit 2
fi

# Get study serires in dest Pacs:

echo "About to execute: findscu -b $calling_ae -c $destPacsConnString $dest_ssl_opts -L SERIES -m StudyInstanceUID=$study -r SeriesInstanceUID |  grep 0020,000E | awk -F'[\\[\\]]' '{print $2}' | grep "\S" | sort -u"

findscu -b $calling_ae -c $destPacsConnString $dest_ssl_opts -L SERIES -m StudyInstanceUID=$study -r SeriesInstanceUID |  grep 0020,000E | awk -F'[\\[\\]]' '{print $2}' | grep "\S" | sort -u >$destSeriesFile

nSeriesOnDestPacs=$(cat $destSeriesFile | wc -l  || echo 0)

if [ "$nSeriesOnDestPacs" -gt 0 ] ; then
	echo "INFO: Number of series on $source_host : $nSeriesOnDestPacs"
else
	echo "ERROR: Problem getting series list on $source_host ,or number of series is 0"
	exit 3
fi

#compare source series with dest series

seriesDiff=$(comm -23 $sourceSeriesFile $destSeriesFile | grep "\S" )

if [ -z "$seriesDiff" ]; then
	echo "INFO: VERIFY  $study instances on $source_host ok"
	exit 0
else
	echo "ERROR: VERIFY $study instances on $source_host missing in $dest_host : $seriesDiff"
	exit 4
fi

