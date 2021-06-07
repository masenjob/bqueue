#!/bin/bash
# Clean all queues
# THIS ERASES ALL FILES FROM ALL QUEUE DIRS!!!
set -u
source ./bqueue.conf
export new deliver process failed finished

rm $new/*
rm $deliver/*
rm $process/*
rm $failed/*
rm $finished/*
