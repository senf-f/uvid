#!/bin/bash

# Default values
source_text="( - )"
author="[ - ]"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        "uvid")
            command_name=$1
            ;;
        -s)
            shift
            # Check if source contains spaces and add quotes if needed
            if [[ "$1" == *" "* ]]; then
		source_text="($1)"
            else
		source_text="($1)"
            fi
            ;;
        -a)
            shift
            # Check if author contains spaces and add quotes if needed
            if [[ "$1" == *" "* ]]; then
                author="[$1]"
            else
                author="[$1]"
            fi
            ;;
        *)
            # Check if the first argument is the text entry
            if [[ "$1" == *'"'* && "$1" == *'"'* ]]; then
                text_entry="$1"
            else
                text_entry="$1"
            fi
            ;;
    esac
    shift
done

# Check if the required argument is provided
if [ -z "$text_entry" ]; then
    echo "Usage: uvid \"some text entry\" -s \"source\" -a \"author\""
    exit 1
fi

# Create log file if it doesn't exist
log_file="uvid_$(date +'%Y').log"
touch "$log_file"

# Get current timestamp
timestamp=$(date +'%d.%m.%Y %H:%M')

# Append entry to the log file
echo "[$timestamp] $text_entry $author $source_text" >> "$log_file"

echo "Entry added to $log_file"

