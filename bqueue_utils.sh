# bqueue_utils.sh
# Utility functions for bqueue operations
#
# 2022 Mauricio Asenjo
# version 2.2

#logs the given string to the logfile with timestamp
log ()
{
    local now=$(date +%Y-%m-%d_%H:%M:%S)
    echo $now" "$@ >> $logdir/$logfile
}

# Count jobs (files) in a queue, takes queue_name as argument
job_count ()
{
    local subqueue=$1
    local count=$(find $subqueue -maxdepth 1 -type f -name '*.job' -print | wc -l)
    echo $count
}

# Moves jobs from "in" to "deliver" queue
deliver_jobs ()
{
    IFS=$'\n'
    for file in $(find $in -maxdepth 1 -type f -name '*.job'  -exec basename {} \; | head -$batch)
    do
        msg="INFO: moving "$file" job to "$deliver
                echo $msg
                log $msg
        mv $in/$file $deliver
    done
}

# Get specified job from the "deliver" queue to the "process" queue and
# and execute the worker over the job in the background
process_job ()
{
    local num_jobs=$1
    IFS=$'\n'
    for file in $(find $deliver -maxdepth 1 -type f -name '*.job'  -exec basename {} \; | head -$num_jobs)
    do
        msg="INFO: moving "$file" job to "$process
                echo $msg
                log $msg
        mv $deliver/$file $process
        execute_job $file &
    done
}

# Execute the worker script over the specified job until success or
# until retry times runs out
execute_job ()
{
    local job=$1
        local jobfile=$process/$job
        local jobfilelog=$process/$job".log"
        local jobfilepid=$process/$job".pid"
        if [ -f $jobfilepid ]
        then
                msg="ERROR: The job $jobfile is already running. Pidfile found: $jobfilepid"
                echo $msg
                log $msg
                exit 1
        fi
        echo $BASHPID > $jobfilepid
        trap "rm $jobfilepid $jobfilelog" EXIT
    local try=0
    local successful=0
    while [[ $try -lt $retry ]] && [[ $successful -eq 0 ]]
    do
                msg="INFO: Executing job $job, attempt $try"
                echo $msg
                log $msg
        $workscript "$(cat $jobfile)" 2>&1 > $jobfilelog
        result=$?
        if [ $result -eq 0 ]
        then
            successful=1
        fi
                msg="INFO: Execution of job $job finished. Successful=$successful"
                echo $msg
                log $msg
        try=$(( $try + 1 ))
    done
    if [ $successful -eq 1 ]
    then
                msg="INFO: moving "$job" job to "$finished
                echo $msg
                log $msg
                cp $jobfile $out
        mv $jobfile $finished
    else
        msg="INFO: moving "$job" job to "$failed
                echo $msg
                log $msg
        mv $jobfile $failed
                cp $jobfilelog $failed
    fi
        echo "JOB $job :" >> $logdir/$logprocfile
        cat $jobfilelog >> $logdir/$logprocfile
        rm $jobfilelog
        rm $jobfilepid
}

# check if dir exists, create it if it doesn't
init_dir ()
{
    local result=0
    local dir=$1
    if [ ! -d $dir ]
    then
        mkdir -p $dir
    fi
}

# Run scripts on extcheck dir and get their exit statuses
# return the logical AND of all of them
# scripts placed there should check for any external condition that
# should be met to allow the queue to continue to process jobs
# like disk space remaining , etc
ext_check ()
{
local status=0
for i in $(find $extcheck -maxdepth 1 -type f -name "*.sh" -print); do
    if [ -x "$i" ]; then
                ./$i
                status=$(( $status + $? ))
                msg="INFO: External check $i result: $status"
                log $msg
    fi
done
echo $status
}

# returns the status of the queue
# "stopped" : queue is not running
# "running" : queue is running
# "paused"      : queue is paused by an exteral check script
# "interrupted" : pid file is present, but queue is not running
queue_status ()
{
local status="stopped"
local queue=$1
if [ -f $PID_file ]; then
        if ps -p $(cat $PID_file)>/dev/null; then
                status="running"
                if [ $(ext_check) -ne 0 ]; then
                        status="paused"
                fi
        else
                status="interrupted"
        fi
fi
echo $status
}

# Simple file based locking
# Checks if there is a lock file, and if not
# creates one, returning 0 as it got the lock
get_lock ()
{
        local lockfile=$1
        if [ -f $lockfile ]; then
                # lockfile exists, couldn'd get the lock
                return 1
        else
                touch $lockfile
                return $?
        fi
}

# Removes the lock file if there is one
# returning 0 if successful or if there was no lock
unlock ()
{
        local lockfile=$1
        if [ -f $lockfile ]; then
                # lockfile exists, so we delete it
                rm $lockfile
                return $?
        else
                return 0
        fi
}