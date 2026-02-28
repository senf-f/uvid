#!/bin/bash

show_help() {
    echo "uvid - log timestamped entries to a yearly log file"
    echo ""
    echo "Usage:"
    echo "  uvid \"text entry\" [-s \"source\"] [-a \"author\"]"
    echo "  uvid              (interactive mode)"
    echo ""
    echo "Arguments:"
    echo "  \"text entry\"   The text to log (required)"
    echo "  -s \"source\"    Source of the entry (optional)"
    echo "  -a \"author\"    Author of the entry (optional)"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Log file: YEAR_uvid.log (created in the current directory)"
    echo ""
    echo "Example:"
    echo "  uvid \"some insight\" -s \"book title\" -a \"John Doe\""
}

log_entry() {
    local entry="$1"
    local log_file="$(date +'%Y')_uvid.log"
    touch "$log_file"
    echo "$entry" >> "$log_file"
    echo ""
    echo "Logged: $entry"
    echo "File:   $log_file"
}

timestamp=$(date +'%d.%m.%Y %H:%M')

if [[ "$#" -eq 0 ]]; then
    # Interactive mode
    read -p "Text: " text_entry
    if [ -z "$text_entry" ]; then
        echo "Text entry is required."
        exit 1
    fi

    read -p "Source: " source_input
    read -p "Author: " author_input

    entry="[$timestamp] $text_entry"
    [ -n "$author_input" ] && entry="$entry [$author_input]"
    [ -n "$source_input" ] && entry="$entry ($source_input)"

    log_entry "$entry"
else
    # Non-interactive mode
    source_text="( - )"
    author="[ - ]"

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            -s)
                shift
                source_text="($1)"
                ;;
            -a)
                shift
                author="[$1]"
                ;;
            *)
                text_entry="$1"
                ;;
        esac
        shift
    done

    if [ -z "$text_entry" ]; then
        echo "Usage: uvid \"some text entry\" -s \"source\" -a \"author\""
        exit 1
    fi

    log_entry "[$timestamp] $text_entry $author $source_text"
fi
