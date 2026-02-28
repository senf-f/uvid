#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/uvid.sh"

show_help() {
    echo "uvid - log timestamped entries to a yearly log file"
    echo ""
    echo "Usage:"
    echo "  uvid \"text entry\" [-s \"source\"] [-a \"author\"]"
    echo "  uvid              (interactive mode)"
    echo ""
    echo "Arguments:"
    echo "  \"text entry\"      The text to log (required)"
    echo "  -s \"source\"       Source of the entry (optional)"
    echo "  -a \"author\"       Author of the entry (optional)"
    echo ""
    echo "Flags:"
    echo "  --list [n]        Show last n entries from this year's log (default: 10)"
    echo "  --search \"term\"   Search all log files for a term"
    echo "  --install         Install uvid to /usr/local/bin"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Log file: YEAR_uvid.log (created in the current directory)"
    echo ""
    echo "Example:"
    echo "  uvid \"some insight\" -s \"book title\" -a \"John Doe\""
}

do_install() {
    local target="/usr/local/bin/uvid"
    if cp "$SCRIPT_PATH" "$target" && chmod +x "$target" 2>/dev/null; then
        echo "Installed to $target"
    else
        echo "Permission denied. Try:"
        echo "  sudo cp \"$SCRIPT_PATH\" $target && sudo chmod +x $target"
    fi
}

show_list() {
    local n="${1:-10}"
    local log_file="$(date +'%Y')_uvid.log"
    if [ ! -f "$log_file" ]; then
        echo "No log file found for this year."
        exit 0
    fi
    echo "Last $n entries from $log_file:"
    echo ""
    tail -n "$n" "$log_file"
}

do_search() {
    local term="$1"
    if [ -z "$term" ]; then
        echo "Usage: uvid --search \"term\""
        exit 1
    fi
    local files=(*_uvid.log)
    if [ ! -f "${files[0]}" ]; then
        echo "No log files found."
        exit 0
    fi
    grep -Hi --color=always "$term" *_uvid.log
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

# Handle special flags
case $1 in
    --help|-h)
        show_help; exit 0 ;;
    --install)
        do_install; exit 0 ;;
    --list)
        n=10
        [[ "$2" =~ ^[0-9]+$ ]] && n="$2"
        show_list "$n"; exit 0 ;;
    --search)
        do_search "$2"; exit 0 ;;
esac

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
    # Inline mode
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -s) shift; source_text="($1)" ;;
            -a) shift; author="[$1]" ;;
            *)  text_entry="$1" ;;
        esac
        shift
    done

    if [ -z "$text_entry" ]; then
        echo "Usage: uvid \"some text entry\" -s \"source\" -a \"author\""
        exit 1
    fi

    entry="[$timestamp] $text_entry"
    [ -n "$author" ] && entry="$entry $author"
    [ -n "$source_text" ] && entry="$entry $source_text"

    log_entry "$entry"
fi
