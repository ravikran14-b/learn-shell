#!/bin/bash

# This script demonstrates the use of special variables in bash

echo "All args passed to the script: $@"
echo "All args passed to the script as word: $*"
echo "Number of args passed to the script: $#"
echo "First arg passed to the script: $1"
echo "Second arg passed to the script: $2"
echo "Third arg passed to the script: $3"
echo "Script name: $0"
echo "Real path of the script: $(realpath $0)"
sleep 10 &
echo "PID of the current running script: $$"
wait $! 
echo "Which user is running this script: $USER"
echo "present working directory: $PWD"
echo "home directory of the user running this script: $HOME"
echo "exit status of the last command executed: $?"