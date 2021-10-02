#!/bin/bash
#
# dicom_verify.sh
# verify that a study specified in
# command line has at least the same number
# of instances or more in destination pacs 
# than in source pacs
#
# 2021 Mauricio Asenjo
# version 0.1

# Get the script directory
dir=$(dirname ${BASH_SOURCE[0]})

# Config file (relative to script location)
config=$dir"/"$(basename $0)".conf"


# defaults
source_ssl="FALSE"
dest_ssl="FALSE"
timeout="10m"

if [ -f $config ]
then
        source $config
else
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

# Returns 0 if a value is an integer, 1 otherwise
isdecimal() {
  # filter octal/hex/ord()
  num=$(printf '%s' "$1" | sed "s/^0*\([1-9]\)/\1/; s/'/^/")
  test "$num" && printf '%f' "$num" >/dev/null 2>&1
}



# Get n° of studies in source Pacs:

echo "About to execute: findscu -b $calling_ae -c $sourcePacsConnString $ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}'"

nInstancesOnSourcePacs=$(findscu -b $calling_ae -c $sourcePacsConnString $source_ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}')

if isdecimal "$nInstancesOnSourcePacs" ; then
	echo "INFO: Number of instances on $source_host : $nInstancesOnSourcePacs"
else
	echo "ERROR: Problem getting number of instances on $source_host"
	exit 2
fi

# Get n° of studies in dest Pacs:

echo "About to execute: findscu -b $calling_ae -c $destPacsConnString $ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}'"

nInstancesOnDestPacs=$(findscu -b $calling_ae -c $destPacsConnString $dest_ssl_opts -m StudyInstanceUID=$study -r NumberOfStudyRelatedInstances | grep NumberOfStudyRelatedInstances | grep -v '\[\]' | awk -F'[\\[\\]]' '{print $2}')

if isdecimal "$nInstancesOnDestPacs" ; then
	echo "INFO: Number of instances on $dest_host : $nInstancesOnDestPacs"
else
	echo "ERROR: Problem getting number of instances on $dest_host"
	exit 3
fi

if [ "$nInstancesOnSourcePacs" -gt "$nInstancesOnDestPacs" ] ; then
	echo "ERROR: VERIFY study $study instances on $source_host : $nInstancesOnSourcePacs ,  $dest_host : $nInstancesOnDestPacs"
	exit 4
else
	echo "INFO: VERIFY study $study instances on $source_host : $nInstancesOnSourcePacs ,  $dest_host : $nInstancesOnDestPacs"
	exit 0
fi
