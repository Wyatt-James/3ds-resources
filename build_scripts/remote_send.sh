#!/bin/bash

echo Running remote_send.sh

# remote_send.sh
# Authors: Wyatt-James
#
# A script that sends a 3DSX file to a 3DS running 3dslink.
#
# Usage: remote_send.sh [sleep duration]
#   sleep duration: duration to sleep after the file has finished sending, in seconds
#
# Return codes: returns the code of the 3dslink command, or a kRET_ value as specified below.

kRET_INVALID_SYNTAX=1
kIP_ADDR="192.168.0.1"
kEXEC_FILE="build/executable.3dsx"
kEXEC_COMMAND="3dslink -a \"$kIP_ADDR\" \"$kEXEC_FILE\""

# Check arg count
if [ "$#" -ge 2 ]
then
  echoerr "Invalid syntax! Syntax: remote_send.sh [sleep duration]"
  exit $kRET_INVALID_SYNTAX
fi

if [ "$#" -eq 1 ]
then
    kSLEEP_DURATION=$1
else
    kSLEEP_DURATION=0
fi

echo "Sending with $kEXEC_COMMAND"
eval "$kEXEC_COMMAND"
ret_code=$?

echo "3DSLink exited with code $ret_code"

if [[ $kSLEEP_DURATION != 0 ]]
then
    echo "Sleeping for $kSLEEP_DURATION seconds."
    sleep $kSLEEP_DURATION
    echo "Finished sleeping."
fi

echo Finished remote_send.sh
exit $ret_code
