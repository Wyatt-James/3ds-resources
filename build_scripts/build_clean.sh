#!/bin/bash

echo Running build_clean.sh

# build_clean.sh
# Authors: Wyatt-James
#
# A script that runs 'make clean' inside of docker.
#
# Usage: build_clean.sh
#
# Return codes: returns the code of the docker command.
#
# Semantics:
# - Sets the CURRENT_BUILD_VERSION flag to CLEAN.
# - Sets the kLAST_BUILD_RESULT flag to the code returned by this script.

kFLAG_FILE=build_flags.txt
kBUILD_FLAG_VAL=CLEAN
kBUILD_FLAG=CURRENT_BUILD_VERSION
kLAST_BUILD_RESULT=LAST_BUILD_RESULT
kMOUNT_DIRECTORY=$(pwd):/game_name
kDOCKER_CONTAINER=wyatt_james/game_name:temp

echo "Build flag file: $kFLAG_FILE"
echo "Build flag val: $kBUILD_FLAG_VAL"
echo "Build command: $kBUILD_COMMAND"
echo "Docker Container: $kDOCKER_CONTAINER"

$(bash build_scripts/flag_set.sh "$kFLAG_FILE" "$kBUILD_FLAG" "IN_PROGRESS")

echo "Cleaning with docker run --rm -v $kMOUNT_DIRECTORY $kDOCKER_CONTAINER make clean"
docker run --rm -v $kMOUNT_DIRECTORY $kDOCKER_CONTAINER make clean
ret_code=$?

echo "Build line returned code $ret_code"

$(bash build_scripts/flag_set.sh "$kFLAG_FILE" "$kBUILD_FLAG" "$kBUILD_FLAG_VAL")
flag_retcode_1=$?
$(bash build_scripts/flag_set.sh "$kFLAG_FILE" "$kLAST_BUILD_RESULT" "$ret_code")
flag_retcode_2=$?

if [[ "$flag_retcode_1$flag_retcode_2" != "00" ]]; then
    echoerr "Could not set post-build flags."
    exit 3
fi

echo Finished build_clean.sh
exit $ret_code
