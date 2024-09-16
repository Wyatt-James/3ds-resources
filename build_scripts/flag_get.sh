#!/bin/bash

# flag_get.sh
# Authors: Wyatt-James
#
# Retrieves a flag's value from a given file.
#
# Usage: flag_get.sh <flag file> <flag name>
#   flag file:  text file containing flags to parse
#   flag name:  flag to retrieve the value of
#
# The return value is printed to STDOUT.
#
# Semantics:
# - Reading is not atomic
# - The first value found is what is returned. Duplicate counts are logged.
# - If the flag is not found, the returned string will be empty.
# - The file is not modified
# - If no flag file exists, one will be created with the flag IS_FLAG_FILE:TRUE pre-populated.
# 
# Return codes: specified below


kRET_SUCCESS=0
kRET_INVALID_SYNTAX=1
kRET_FLAG_FILE_COULD_NOT_BE_FOUND_OR_CREATED=2
# kRET_FILE_IS_NOT_A_FLAG_FILE=3
kRET_INVALID_KEY_FORMAT=4
# kRET_INVALID_VALUE_FORMAT=5
# kRET_CANNOT_OVERWRITE_PROTECTED_FLAG=6
kRET_KEY_NOT_FOUND=7

echoerr() { echo "$@" 1>&2; }
debug_log() {
    # echoerr "$@"
    :
}

debug_log "running flag_get.sh"

# Check arg count
if [ "$#" -ne 2 ]
then
  echoerr "Invalid syntax! Syntax: flag_get.sh <flag file> <flag name>"
  exit $kRET_INVALID_SYNTAX
fi

kFLAG_FILE=$1
kFLAG_KEY=$2
kFLAG_NAME_REGEX='^([0-9a-zA-Z_]+)$'
kFLAG_REGEX='^([0-9a-zA-Z_]+):([0-9a-zA-Z_]+)$'
values_found=()

debug_log "Flag file: $kFLAG_FILE"
debug_log "Flag name: $kFLAG_KEY"

# Check key format
if [[ ! "$kFLAG_KEY" =~ $kFLAG_NAME_REGEX ]]
then
    echoerr "Invalid flag name format for flag $kFLAG_KEY. Exiting."
    exit $kRET_INVALID_KEY_FORMAT
fi

# Create flag file
if [ ! -f "$kFLAG_FILE" ]
then
    echoerr "Flag file \"$kFLAG_FILE\" does not exist. Creating an empty file."
    touch "$kFLAG_FILE"
    
    # If it couldn't be created, give up
    if [ ! -f "$kFLAG_FILE" ]
    then
        echoerr "Could not create flag file $kFLAG_FILE."
        exit $kRET_FLAG_FILE_COULD_NOT_BE_FOUND_OR_CREATED
    fi
    
    echo "IS_FLAG_FILE:TRUE" > "$kFLAG_FILE"
fi

# Iterate all lines of the file for the flag we want
while read -r line;
do
    if ! [[ "$line" =~ $kFLAG_REGEX ]]
    then
        debug_log "Ignoring line with bad format: $line"
    else
        parsed_key=${BASH_REMATCH[1]}
        parsed_value=${BASH_REMATCH[2]}
        debug_log "Good format: $line. Parsed: $parsed_key, $parsed_value"

        # Add all values with the correct key
        if [[ "$parsed_key" == "$kFLAG_KEY" ]]
        then
            values_found+=($parsed_value)
        fi
    fi
done < "$kFLAG_FILE"

num_values_found=${#values_found[*]}
ret_code=$kRET_SUCCESS
debug_log "Num values: $num_values_found"
debug_log "Values: ${values_found[*]}"
debug_log "Retval: $ret_val"

if (( num_values_found == 0 ))
then
    debug_log "Did not find the requested key."
    ret_val=""
    ret_code=$kRET_KEY_NOT_FOUND
else
    if (( num_values_found >= 2 ))
    then
        echoerr "Found $num_values_found copies of flag $kFLAG_KEY. Returning the first instance."
    else
        debug_log "Found the key exactly once."
    fi

    ret_val=${values_found[0]}
    ret_code=$kRET_SUCCESS
    echo $ret_val
fi

debug_log "finished flag_get.sh"
exit $ret_code
