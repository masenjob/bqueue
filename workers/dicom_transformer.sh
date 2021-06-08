#!/bin/bash
#
# dicom_transformer.sh
# 
# Reads and generates an xml metadata file for 
# each dcm file under the specified source directory
# (which must correspond to a complete study)
# Generates a transformed study with the mappings
# specified by the transform() function
# into the destination directory
# 
# 2020 Mauricio Asenjo
# version 0.4

# set -u

if [ -z $1 ]
then
	echo "ERROR: study not specified"
	exit 1
else
	study=$1
fi

# Tranform routine
# Apply all the neede transformation to the xml
# to generate the transformed dcm file
transform ()
{
	local xml=$1
	#Accession number xpath:
	local acc_path="/NativeDicomModel/DicomAttribute[@tag="00080050"]/Value"
	
	#RequestAttributeSequence (1) Accession Number xpath:
	local ras_1_acc_path="/NativeDicomModel/DicomAttribute[@tag="00400275"]/Item[@number="1"]/DicomAttribute[@tag="00080050"]/Value"

	#RequestAttributeSequence (1) Scheduled Procedure Step ID xpath
	local ras_1_spsi_path="/NativeDicomModel/DicomAttribute[@tag="00400275"]/Item[@number="1"]/DicomAttribute[@tag="00400009"]/Value" 

	#RequestAttributeSequence (2) Accession Number xpath:
	local ras_2_acc_path="/NativeDicomModel/DicomAttribute[@tag="00400275"]/Item[@number="2"]/DicomAttribute[@tag="00080050"]/Value"

	#StudyID xpath:
	local sid_path="/NativeDicomModel/DicomAttribute[@tag="00200010"]/Value"

	# Get the Accession number  from the xml file:
	current_acc=$(xmlstarlet sel -t -v $acc_path $xml)
	if [ -z $current_acc ]; then
		echo "ERROR: Missing accession number from $xml !"
		exit 1
	fi

	# Get the RequestAttributeSequence (1) Accession Number value:
	xmlstarlet sel -t -v $ras_1_acc_path $xml

	# Get the RequestAttributeSequence (1) Scheduled Procedure Step ID value:
	xmlstarlet sel -t -v $ras_1_spsi_path $xml

	# Get the RequestAttributeSequence (2) Accession Number value:
	xmlstarlet sel -t -v $ras_2_acc_path $xml

	# Apply mappings:
	# Accession Number
	new_acc="SC$current_acc"
	echo "INFO: mapping $acc_path"
	xmlstarlet ed --inplace -u $acc_path -v $new_acc $xml
	# The other dicom attr if present
	for i in $ras_1_acc_path $ras_1_spsi_path $ras_2_acc_path $sid_path; do
		if [ ! -z $i ]; then
		echo "INFO: mapping $i"
			xmlstarlet ed --inplace -u $i -v $new_acc $xml
		fi
	done
}


sourcedir="/cache/incoming"
destdir="/cache/transformed"

sourcestudy=$sourcedir/$study
deststudy=$destdir/$study

# Remove destination study if it exists
rm -rf $deststudy

# Create the destination study directory structure
echo "INFO: Creating destination dir for study $study"
rsync -a --include='*/' --exclude='*' $sourcestudy $destdir/

images=1

for f in $(find $sourcestudy -name "*.dcm" -printf "%P\n") 
do
	echo "INFO: Starting transform of image $image"
	metadata=$deststudy/$f".xml"
	sourcedcm=$sourcestudy/$f
	destdcm=$deststudy/$f
	
	# extract the metadata
	echo "INFO: Extracting metadata to $metadata"
	JAVA_OPTS="-Xshare:on" dcm2xml -K $sourcedcm > $metadata
	if [ "$?" -ne 0 ] ; then
		echo "ERROR: XML extract error on $sourcedcm. Exiting"
		exit 1
	fi
	# transform the metadata
	echo "INFO: Applying transformations to $metadata"
	transform $metadata
	
	# generate a new dcm file with the metadata and
	# pixel data from original study
	echo "INFO: Generating transformed dcm file $destdcm"
	JAVA_OPTS="-Xshare:on" xml2dcm -x $metadata -i $sourcedcm -o $destdcm
	if [ "$?" -ne 0 ] ; then
		echo "ERROR: new dcm file generation FAILED from $sourcedcm with $metadata. Exiting"
		exit 1
	fi
	rm $metadata
	images=$(( $images + 1 ))
done
echo "INFO: $images dcm files processed"
#If we got here, delete the source study
rm -rf $sourcestudy
