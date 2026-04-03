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
    echo "  --edit            Edit an existing entry"
    echo "  --delete          Delete an existing entry"
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

parse_entry() {
    local line="$1"
    # Extract timestamp: [DD.MM.YYYY HH:MM]
    local ts_re='^\[([0-9.]+[[:space:]][0-9:]+)\]'
    if [[ "$line" =~ $ts_re ]]; then
        p_timestamp="[${BASH_REMATCH[1]}]"
    fi

    # Remove timestamp from line
    local rest="${line#$p_timestamp }"

    # Extract source (trailing parenthesized text)
    p_source=""
    local src_re='[(]([^)]+)[)]$'
    if [[ "$rest" =~ $src_re ]]; then
        p_source="${BASH_REMATCH[1]}"
        rest="${rest% ($p_source)}"
    fi

    # Extract author (trailing bracketed text)
    p_author=""
    local auth_re='[[]([^]]+)[]]$'
    if [[ "$rest" =~ $auth_re ]]; then
        p_author="${BASH_REMATCH[1]}"
        rest="${rest% [$p_author]}"
    fi

    # Remaining text is the entry text (trim trailing whitespace)
    p_text=$(echo "$rest" | sed 's/[[:space:]]*$//')
}

pick_entry() {
    echo "Browse recent or search? (B/s)"
    read -p "> " mode
    [ -z "$mode" ] && mode="b"

    local entries=()
    local files=()

    if [[ "$mode" == "s" ]]; then
        read -p "Search term: " term
        local log_files=(*_uvid.log)
        if [ ! -f "${log_files[0]}" ]; then
            echo "No log files found."
            exit 0
        fi
        while IFS= read -r match; do
            local file="${match%%:*}"
            local line="${match#*:}"
            entries+=("$line")
            files+=("$file")
        done < <(grep -iH "$term" *_uvid.log)
        if [ ${#entries[@]} -eq 0 ]; then
            echo "No matches found."
            exit 0
        fi
    else
        local log_file="$(date +'%Y')_uvid.log"
        if [ ! -f "$log_file" ]; then
            echo "No log file found for this year."
            exit 0
        fi
        while IFS= read -r line; do
            entries+=("$line")
            files+=("$log_file")
        done < <(tail -n 10 "$log_file")
        if [ ${#entries[@]} -eq 0 ]; then
            echo "No entries found."
            exit 0
        fi
    fi

    echo ""
    for i in "${!entries[@]}"; do
        echo "  $((i + 1)). ${entries[$i]}"
    done
    echo ""
    read -p "Select entry number: " selection

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#entries[@]} ]; then
        echo "Invalid selection."
        exit 1
    fi

    picked_line="${entries[$((selection - 1))]}"
    picked_file="${files[$((selection - 1))]}"
}

do_edit() {
    pick_entry
    parse_entry "$picked_line"

    echo ""
    echo "Editing entry. Press Enter to keep current value."
    echo ""

    local display_author="${p_author:-(none)}"
    local display_source="${p_source:-(none)}"

    read -p "Text [$p_text]: " new_text
    read -p "Author [$display_author]: " new_author
    read -p "Source [$display_source]: " new_source

    # Keep current values if Enter pressed
    [ -z "$new_text" ] && new_text="$p_text"

    # For author/source: Enter=keep, space-only=clear
    if [ -z "$new_author" ]; then
        new_author="$p_author"
    elif [[ "$new_author" =~ ^[[:space:]]+$ ]]; then
        new_author=""
    fi

    if [ -z "$new_source" ]; then
        new_source="$p_source"
    elif [[ "$new_source" =~ ^[[:space:]]+$ ]]; then
        new_source=""
    fi

    # Reconstruct entry
    local new_entry="$p_timestamp $new_text"
    [ -n "$new_author" ] && new_entry="$new_entry [$new_author]"
    [ -n "$new_source" ] && new_entry="$new_entry ($new_source)"

    # Replace in file using temp file
    local tmpfile=$(mktemp)
    local replaced=false
    while IFS= read -r line; do
        if [ "$line" = "$picked_line" ] && [ "$replaced" = false ]; then
            echo "$new_entry"
            replaced=true
        else
            echo "$line"
        fi
    done < "$picked_file" > "$tmpfile"
    mv "$tmpfile" "$picked_file"

    echo ""
    echo "Updated: $new_entry"
}

do_delete() {
    pick_entry

    echo ""
    echo "  $picked_line"
    echo ""
    read -p "Delete this entry? (Y/n) " confirm

    if [[ -n "$confirm" && "$confirm" != "y" ]]; then
        echo "Cancelled."
        exit 0
    fi

    local tmpfile=$(mktemp)
    local deleted=false
    while IFS= read -r line; do
        if [ "$line" = "$picked_line" ] && [ "$deleted" = false ]; then
            deleted=true
        else
            echo "$line"
        fi
    done < "$picked_file" > "$tmpfile"
    mv "$tmpfile" "$picked_file"

    echo "Deleted."
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
    --edit)
        do_edit; exit 0 ;;
    --delete)
        do_delete; exit 0 ;;
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
