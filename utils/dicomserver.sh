#!/bin/bash
# Dicom receiver
# starts a Dicom Server on the specified port
# and stores received studies on the $dest_dir
#
# requires dcm4che 5
#
# 2021 Mauricio Asenjo
# version 3

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
        echo "AET=<AET of the dicomserver>"
        echo "port=<port of the dicom server>"
        echo "recv_dir=<absolute path of the destination directory>"
        echo "dir_format=<format of the directories where the study is stored"
        echo "#example: dir_format='{00080050}/{0020000D}/{0020000E}/{00080018}.dcm'"
        exit 1
fi

# Check if we got a parameter
if [ -z $1 ]; then
        echo "usage:  $0 start | stop | status"
        exit 0
fi

action=$1

 # Start storescp
start_dicomserver ()
{

		if ( is_running ) ; then
			echo " dicomserver is already running on pid $(is_running)"
			return 1
		else
			echo "STARTING $0"
			nohup storescp -b $AET:$port --directory $recv_dir --filepath $dir_format > $logfile &
			local status=$?
			if [ ! "$status" -eq 0 ] ; then
				echo "Could not start $0 , see $logfile for details"
				return 2
			else
				echo "$0 STARTED"
				return $status
			fi
		fi
}


stop_dicomserver ()
{
	if ( is_running ); then
		kill $(is_running)
		local status=$?
		if [ $status = 0 ] ; then
			echo "$0 STOPPED"
		else
			echo "Error stopping $0 in pid $(is_running)"
		fi
	else
        echo "$0 not running"
        local status=2
    fi
	return $status
}

status_dicomserver ()
{
	# Prints the status of the dicomserver service
    if ( is_running ); then
        echo "$0 Running on pid $(is_running)"
    else
        echo "$0 is not running"
    fi
}

is_running ()
{
	# Prints the value of the pid of the storescp process , or -1 if not found
	local pid=$(ps ax | grep storescp | grep $AET":"$port | awk '{print $1}')
	if [ -z $pid ]; then
		echo -1
		return 1
	else
		echo $pid
		return 0
	fi
}

logfile=$dir"/"$(basename $0)".log"


case $action in

        status)
                status_dicomserver
                ;;

        start)
                echo "Starting $0 :"
                start_dicomserver
                ;;

        stop)
                echo "Stopping $0 :"
                stop_dicomserver
                ;;

        *)
                echo $action": unknown option"
                exit 1
                ;;
esac

