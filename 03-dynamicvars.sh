#!/bin/bash

### Execute a command and take output in variable (dynamic variable) VARIABLE=$(command)

## +%s states the seconds till now from 1970
START_TIME=$(date +%s)
echo "Script started execution at: $START_TIME"

#stop for 10 seconds
sleep 10 

END_TIME=$(date +%s)
echo "Script completed execution at: $END_TIME"

TOTAL_TIME=$(($END_TIME-$START_TIME))

## Total time taken to run this command
echo "Total time taken: $TOTAL_TIME Seconds"
