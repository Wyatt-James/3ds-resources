#!/bin/bash

echo Running build_generic.sh

# build_generic.sh
# Authors: Wyatt-James
#
# A generic build script. It accepts a complete build command and executes it, while setting a build flag.
#
# Usage: build_generic.sh <flag file> <build flag value> <build command>
#   flag file:        text file containing flags to parse
#   build flag value: value to set flag CURRENT_BUILD_VERSION to in the flag file
#   build command:    line executed to build
#
# Return codes: returns the code of the build command, or a kRET_ value as specified below.
#
# Semantics:
# - Sets the CURRENT_BUILD_VERSION flag to the value passed in through the command line.
# - Sets the kLAST_BUILD_RESULT flag to the code returned by this script.

# kRET_FLAG_SUCCESS=0
# kRET_FLAG_INVALID_SYNTAX=1
# kRET_FLAG_FLAG_FILE_COULD_NOT_BE_FOUND_OR_CREATED=2
# kRET_FLAG_FILE_IS_NOT_A_FLAG_FILE=3
# kRET_FLAG_INVALID_KEY_FORMAT=4
# kRET_FLAG_INVALID_VALUE_FORMAT=5
# kRET_FLAG_CANNOT_OVERWRITE_PROTECTED_FLAG=6
kRET_FLAG_KEY_NOT_FOUND=7

echoerr() { echo "$@" 1>&2; }
debug_log() {
    echoerr "$@"
    :
}

# Check arg count
if [ "$#" -ne 3 ]
then
  echoerr "Invalid syntax! Syntax: build_generic.sh <flag file> <build flag value> <build command>"
  exit $kRET_INVALID_SYNTAX
fi

kFLAG_FILE=$1
kBUILD_FLAG_VAL=$2
kBUILD_COMMAND=$3
kBUILD_FLAG=CURRENT_BUILD_VERSION
kLAST_BUILD_RESULT=LAST_BUILD_RESULT

echo "Build flag file: $kFLAG_FILE"
echo "Build flag val: $kBUILD_FLAG_VAL"
echo "Build command: $kBUILD_COMMAND"

# kBUILD_FLAG_VAL=OPTIMIZED_DEBUG

current_flag_value=$(bash build_scripts/flag_get.sh "$kFLAG_FILE" "$kBUILD_FLAG")
flag_get_retval=$?
if [[ $flag_get_retval != 0 ]]; then

    # If it didn't find the key, just force a clean.
    if [[ $flag_get_retval == $kRET_FLAG_KEY_NOT_FOUND ]]; then
        current_flag_value=IN_PROGRESS
    else
        echoerr "Could not retrieve build flag. Flag script code: $flag_get_retval. Exiting."
        exit 1
    fi
fi

# build clean if the version is different
if [[ "$current_flag_value" != "$kBUILD_FLAG_VAL" ]]
then
    echo "Flag mismatch! Cleaning before build. Previous was: $current_flag_value"
    bash build_scripts/build_clean.sh
    
    if [[ $? != 0 ]]; then
        echoerr "Could not clean. Exiting."
        exit 2
    fi
fi

$(bash build_scripts/flag_set.sh "$kFLAG_FILE" "$kBUILD_FLAG" "IN_PROGRESS")

ret_code=0
eval "$kBUILD_COMMAND"
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

echo Finished build_generic.sh
exit $ret_code
