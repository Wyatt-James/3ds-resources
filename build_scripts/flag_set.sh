#!/bin/bash

# flag_set.sh
# Authors: Wyatt-James
#
# Sets a flag in a given file to a specific value.
# The flag file must have a flag IS_FLAG_FILE with value TRUE, or else writing will abort.
#
# Usage: flag_set.sh <flag file> <flag name> <flag value>
#   flag file:  text file containing flags to parse
#   flag name:  flag to alter the value of
#   flag value: new value for the given flag
#
# Semantics:
# - Writing is atomic, but reading is not.
# - Flags are stored as "NAME:VALUE" (without quotes). Valid characters are alphanumeric, hyphen, and underscore.
# - The order of flags is broadly preserved, except:
#   - The flag's output location will be that of the first instance found, and duplicates will be removed.
# - Lines with invalid format are preserved.
# - Empty lines are removed
# - If no flag file exists, one will be created with the flag IS_FLAG_FILE:TRUE pre-populated.
# 
# Return codes: specified below

kRET_SUCCESS=0
kRET_INVALID_SYNTAX=1
kRET_FLAG_FILE_COULD_NOT_BE_FOUND_OR_CREATED=2
kRET_FILE_IS_NOT_A_FLAG_FILE=3
kRET_INVALID_KEY_FORMAT=4
kRET_INVALID_VALUE_FORMAT=5
kRET_CANNOT_OVERWRITE_PROTECTED_FLAG=6
# kRET_KEY_NOT_FOUND=7

echoerr() { echo "$@" 1>&2; }
debug_log() {
    # echoerr "$@"
    :
}

debug_log "running flag_set.sh"

# Check arg count
if [ "$#" -ne 3 ]
then
  echoerr "Invalid syntax! Syntax: flag_set.sh <flag file> <flag name> <flag value>"
  exit $kRET_INVALID_SYNTAX
fi

kPROTECTED_FLAG="IS_FLAG_FILE"
kFLAG_FILE=$1
kFLAG_KEY=$2
kFLAG_VALUE=$3
kFLAG_NAME_REGEX='^([0-9a-zA-Z_]+)$'
kFLAG_VALUE_REGEX='^([0-9a-zA-Z_]+)$'
kFLAG_REGEX='^([0-9a-zA-Z_]+):([0-9a-zA-Z_]+)$'
flag_written=false
values_found=()

debug_log "Flag file: $kFLAG_FILE"
debug_log "Flag key: $kFLAG_KEY"
debug_log "Flag value: $kFLAG_VALUE"

# Check key format
if [[ ! "$kFLAG_KEY" =~ $kFLAG_NAME_REGEX ]]
then
    echoerr "Invalid flag name format. Exiting."
    exit $kRET_INVALID_KEY_FORMAT
fi

# Check value format
if [[ ! "$kFLAG_VALUE" =~ $kFLAG_VALUE_REGEX ]]
then
    echoerr "Invalid flag value format. Exiting."
    exit $kRET_INVALID_VALUE_FORMAT
fi

# Check that flag is not protected
if [[ "$kFLAG_KEY" == "$kPROTECTED_FLAG" ]]
then
    echoerr "Cannot overwrite protected flag $kPROTECTED_FLAG. Exiting."
    exit $kRET_CANNOT_OVERWRITE_PROTECTED_FLAG
fi

# TODO make to be generic
protected_flag_value=$(bash build_scripts/flag_get.sh "$kFLAG_FILE" "$kPROTECTED_FLAG")

# Check that this file is a real flag file
if [[ "$protected_flag_value" != "TRUE" ]]
then
    echoerr "$kFLAG_FILE is not a valid flag file. Aborting."
    exit $kRET_FILE_IS_NOT_A_FLAG_FILE
fi

# Create flag file
if [ ! -f "$kFLAG_FILE" ]
then
    debug_log "Flag file \"$kFLAG_FILE\" does not exist. Creating an empty file."
    touch "$kFLAG_FILE"
    
    # If it couldn't be created, give up
    if [ ! -f "$kFLAG_FILE" ]
    then
        echoerr "Could not create flag file $kFLAG_FILE."
        exit $kRET_FLAG_FILE_COULD_NOT_BE_FOUND_OR_CREATED
    fi

    echo "IS_FLAG_FILE:TRUE" > "$kFLAG_FILE"
fi

kTEMP_FILE=$(mktemp)
debug_log "Temp file: $kTEMP_FILE"

# Iterate all lines of the input file
while read -r line;
do
    skip_this_line=false

    # Remove empty lines
    if [[ "$line" == "" ]]
    then
        skip_this_line=true
    fi
    
    # Retain lines with bad formatting
    if ! [[ "$line" =~ $kFLAG_REGEX ]]
    then
        debug_log "Retaining line with bad format: $line"
    
    # If the line is correctly formatted, parse it
    else
        parsed_key=${BASH_REMATCH[1]}
        parsed_value=${BASH_REMATCH[2]}
        debug_log "Good format: $line. Parsed: $parsed_key, $parsed_value"

        # If we found the right flag, alter its value, but only write it once.
        if [[ "$parsed_key" == "$kFLAG_KEY" ]]
        then
            skip_this_line=$flag_written
            flag_written=true
            parsed_value="$kFLAG_VALUE"
        fi

        line="$parsed_key:$parsed_value"
    fi

    if [[ $skip_this_line == false ]]
    then
        echo "$line" >> "$kTEMP_FILE"
    fi
done < "$kFLAG_FILE"

# Append value if we never found it
if [[ $flag_written == false ]]
then
    echo "$kFLAG_KEY:$kFLAG_VALUE" >> "$kTEMP_FILE"
fi

# Atomically overwrite source file
mv -f "$kTEMP_FILE" "$kFLAG_FILE"

debug_log "finished flag_set.sh"
exit $kRET_SUCCESS
