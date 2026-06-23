#!/bin/bash

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/uvid.sh"

export LC_ALL="${LC_ALL:-en_US.UTF-8}"

UVID_DIR="${UVID_DIR:-$HOME/.uvid}"
mkdir -p "$UVID_DIR"

get_device() {
    local device=""
    if [ -n "$UVID_DEVICE" ]; then
        device="$UVID_DEVICE"
    elif [ -f "$UVID_DIR/.uvid-device" ]; then
        device=$(cat "$UVID_DIR/.uvid-device")
    fi
    if [ -n "$device" ] && [[ ! "$device" =~ ^[a-z0-9-]+$ ]]; then
        device=""
    fi
    echo "$device"
}

show_help() {
    echo "uvid - log timestamped entries to a monthly log file"
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
    echo "  --list [n]        Show last n entries from this month's log (default: 10)"
    echo "  --search \"term\"   Search all log files for a term"
    echo "  --edit            Edit an existing entry"
    echo "  --delete          Delete an existing entry"
    echo "  --export          Export entries to Markdown"
    echo "    --search \"term\"   Filter by text"
    echo "    --author \"name\"   Filter by author"
    echo "    --year YYYY       Filter by year"
    echo "    --from/--to       Filter by date range (DD.MM.YYYY)"
    echo "  --sync            Sync logs with VPS"
    echo "  --set-device name Set device name for this machine"
    echo "  --verbose         Show device tags in list/search output"
    echo "  --install         Install uvid to /usr/local/bin"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Log file: ~/.uvid/MM-YYYY_uvid.log"
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
    local verbose="$2"
    local log_file="$UVID_DIR/$(date +'%m-%Y')_uvid.log"
    if [ ! -f "$log_file" ]; then
        echo "No log file found for this month."
        exit 0
    fi
    echo "Last $n entries from $log_file:"
    echo ""
    if [ "$verbose" = "true" ]; then
        tail -n "$n" "$log_file"
    else
        tail -n "$n" "$log_file" | strip_device_tag
    fi
}

do_search() {
    local term="$1"
    local verbose="$2"
    if [ -z "$term" ]; then
        echo "Usage: uvid --search \"term\""
        exit 1
    fi
    local files=("$UVID_DIR"/*_uvid.log)
    if [ ! -f "${files[0]}" ]; then
        echo "No log files found."
        exit 0
    fi
    if [ "$verbose" = "true" ]; then
        grep -Hi --color=always "$term" "$UVID_DIR"/*_uvid.log
    else
        grep -Hi --color=always "$term" "$UVID_DIR"/*_uvid.log | strip_device_tag
    fi
}

log_entry() {
    local entry="$1"
    local log_file="$UVID_DIR/$(date +'%m-%Y')_uvid.log"
    touch "$log_file"
    echo "$entry" >> "$log_file"
    echo ""
    echo "Logged: $entry"
    echo "File:   $log_file"
}

parse_entry() {
    local line="$1"
    p_timestamp=""
    p_source=""
    p_author=""
    p_device=""
    local ts_re='^\[([0-9.]+[[:space:]][0-9:]+)\]'
    if [[ "$line" =~ $ts_re ]]; then
        p_timestamp="[${BASH_REMATCH[1]}]"
    fi

    # Strip timestamp using substring arithmetic (avoids glob [...] interpretation)
    local rest="$line"
    if [ -n "$p_timestamp" ]; then
        rest="${rest:${#p_timestamp}+1}"
    fi

    # Extract device tag (trailing {name})
    local dev_re='[{]([^}]+)[}]$'
    if [[ "$rest" =~ $dev_re ]]; then
        p_device="${BASH_REMATCH[1]}"
        local dev_suffix=" {$p_device}"
        rest="${rest:0:${#rest}-${#dev_suffix}}"
    fi

    local src_re='[(]([^)]+)[)]$'
    if [[ "$rest" =~ $src_re ]]; then
        p_source="${BASH_REMATCH[1]}"
        local src_suffix=" ($p_source)"
        rest="${rest:0:${#rest}-${#src_suffix}}"
    fi

    local auth_re='[[]([^]]+)[]]$'
    if [[ "$rest" =~ $auth_re ]]; then
        p_author="${BASH_REMATCH[1]}"
        local auth_suffix=" [$p_author]"
        rest="${rest:0:${#rest}-${#auth_suffix}}"
    fi

    p_text=$(echo "$rest" | sed 's/[[:space:]]*$//')
}

strip_device_tag() {
    sed 's/ {[a-z0-9-]*}$//'
}

pick_entry() {
    echo "Browse recent or search? (B/s)"
    read -p "> " mode
    [ -z "$mode" ] && mode="b"

    local entries=()
    local files=()

    if [[ "$mode" == "s" ]]; then
        read -p "Search term: " term
        local log_files=("$UVID_DIR"/*_uvid.log)
        if [ ! -f "${log_files[0]}" ]; then
            echo "No log files found."
            exit 0
        fi
        while IFS= read -r match; do
            local file="${match%%:*}"
            local line="${match#*:}"
            entries+=("$line")
            files+=("$file")
        done < <(grep -iH "$term" "$UVID_DIR"/*_uvid.log)
        if [ ${#entries[@]} -eq 0 ]; then
            echo "No matches found."
            exit 0
        fi
    else
        local log_file="$UVID_DIR/$(date +'%m-%Y')_uvid.log"
        if [ ! -f "$log_file" ]; then
            echo "No log file found for this month."
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

    IFS= read -rp "Text [$p_text]: " new_text
    IFS= read -rp "Author [$display_author]: " new_author
    IFS= read -rp "Source [$display_source]: " new_source

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
    [ -n "$p_device" ] && new_entry="$new_entry {$p_device}"

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

do_export() {
    shift # consume --export
    local filter_search="" filter_author="" filter_year="" filter_from="" filter_to=""

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --search) shift; filter_search="$1" ;;
            --author) shift; filter_author="$1" ;;
            --year)   shift; filter_year="$1" ;;
            --from)   shift; filter_from="$1" ;;
            --to)     shift; filter_to="$1" ;;
            *) echo "Unknown export option: $1"; exit 1 ;;
        esac
        shift
    done

    # Validate: --year and --from/--to are mutually exclusive
    if [ -n "$filter_year" ] && { [ -n "$filter_from" ] || [ -n "$filter_to" ]; }; then
        echo "Error: --year and --from/--to cannot be combined."
        exit 1
    fi

    # Validate: --from and --to must come together
    if { [ -n "$filter_from" ] && [ -z "$filter_to" ]; } || { [ -z "$filter_from" ] && [ -n "$filter_to" ]; }; then
        echo "Error: --from and --to must both be provided."
        exit 1
    fi

    # Collect log files
    local log_files=()
    if [ -n "$filter_year" ]; then
        for f in $(ls "$UVID_DIR"/*-${filter_year}_uvid.log 2>/dev/null | sort); do
            log_files+=("$f")
        done
    else
        for f in $(ls "$UVID_DIR"/*_uvid.log 2>/dev/null | sort); do
            log_files+=("$f")
        done
    fi

    if [ ${#log_files[@]} -eq 0 ]; then
        echo "No entries found matching the given filters."
        return
    fi

    # Convert DD.MM.YYYY to YYYYMMDD integer
    date_to_int() {
        local d="$1"
        echo "${d:6:4}${d:3:2}${d:0:2}"
    }

    local from_int="" to_int=""
    if [ -n "$filter_from" ]; then
        from_int=$(date_to_int "$filter_from")
        to_int=$(date_to_int "$filter_to")
    fi

    # Collect matching entries
    local matched=()
    for file in "${log_files[@]}"; do
        while IFS= read -r line; do
            [ -z "$line" ] && continue

            # Search filter
            if [ -n "$filter_search" ]; then
                echo "$line" | grep -qi "$filter_search" || continue
            fi

            parse_entry "$line"

            # Author filter
            if [ -n "$filter_author" ]; then
                local lower_author=$(echo "$p_author" | tr '[:upper:]' '[:lower:]')
                local lower_filter=$(echo "$filter_author" | tr '[:upper:]' '[:lower:]')
                [ "$lower_author" != "$lower_filter" ] && continue
            fi

            # Date range filter
            if [ -n "$from_int" ]; then
                local ts_date="${p_timestamp:1:10}"
                local entry_int=$(date_to_int "$ts_date")
                [ "$entry_int" -lt "$from_int" ] && continue
                [ "$entry_int" -gt "$to_int" ] && continue
            fi

            matched+=("$line")
        done < "$file"
    done

    if [ ${#matched[@]} -eq 0 ]; then
        echo "No entries found matching the given filters."
        return
    fi

    # Build header title
    local title="# Uvid Export"
    local parts=()
    if [ -n "$filter_year" ]; then
        parts+=("$filter_year")
    elif [ -n "$filter_from" ]; then
        parts+=("$filter_from – $filter_to")
    fi
    [ -n "$filter_author" ] && parts+=("$filter_author")
    [ -n "$filter_search" ] && parts+=("\"$filter_search\"")
    if [ ${#parts[@]} -gt 0 ]; then
        local joined=$(IFS=', '; echo "${parts[*]}")
        title="$title — $joined"
    fi

    local export_date=$(date +'%d.%m.%Y')
    local export_file="uvid_export_$(date +'%Y-%m-%d').md"

    {
        echo "$title"
        echo "> ${#matched[@]} entries | Exported $export_date"
        echo ""
        echo "---"

        for line in "${matched[@]}"; do
            parse_entry "$line"
            echo ""
            echo "**${p_timestamp}** $p_text"

            local has_author=false has_source=false
            if [ -n "$p_author" ] && [ "$p_author" != "." ]; then
                has_author=true
            fi
            if [ -n "$p_source" ] && [ "$p_source" != "-" ]; then
                has_source=true
            fi

            if $has_author && $has_source; then
                echo "- Author: $p_author | Source: $p_source"
            elif $has_author; then
                echo "- Author: $p_author"
            elif $has_source; then
                echo "- Source: $p_source"
            fi
            if [ -n "$p_device" ]; then
                echo "- Device: $p_device"
            fi
        done
    } > "$export_file"

    echo "Exported ${#matched[@]} entries to $export_file"
}

timestamp=$(date +'%d.%m.%Y %H:%M:%S')

# Handle special flags
case $1 in
    --help|-h)
        show_help; exit 0 ;;
    --install)
        do_install; exit 0 ;;
    --list)
        n=10
        verbose=false
        shift
        [[ "$1" =~ ^[0-9]+$ ]] && { n="$1"; shift; }
        [[ "$1" == "--verbose" ]] && verbose=true
        show_list "$n" "$verbose"; exit 0 ;;
    --search)
        shift; term="$1"; shift
        verbose=false
        [[ "$1" == "--verbose" ]] && verbose=true
        do_search "$term" "$verbose"; exit 0 ;;
    --edit)
        do_edit; exit 0 ;;
    --delete)
        do_delete; exit 0 ;;
    --export)
        do_export "$@"; exit 0 ;;
    --sync)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -x "$SCRIPT_DIR/uvid-sync.sh" ]; then
            "$SCRIPT_DIR/uvid-sync.sh"
        else
            echo "uvid-sync.sh not found or not executable."
            exit 1
        fi
        exit 0 ;;
    --set-device)
        device_name="$2"
        if [ -z "$device_name" ] || [[ ! "$device_name" =~ ^[a-z0-9-]+$ ]]; then
            echo "Invalid device name. Use lowercase letters, numbers, and hyphens only."
            exit 1
        fi
        echo "$device_name" > "$UVID_DIR/.uvid-device"
        echo "Device set to: $device_name"
        exit 0 ;;
esac

if [[ "$#" -eq 0 ]]; then
    # Interactive mode
    read -p "Text: " text_entry
    if [ -z "$text_entry" ]; then
        echo "Text entry is required."
        exit 1
    fi

    read -p "Source [-]: " source_input
    [ -z "$source_input" ] && source_input="-"
    read -p "Author [.]: " author_input
    [ -z "$author_input" ] && author_input="."

    entry="[$timestamp] $text_entry"
    [ -n "$author_input" ] && entry="$entry [$author_input]"
    [ -n "$source_input" ] && entry="$entry ($source_input)"
    device=$(get_device)
    [ -n "$device" ] && entry="$entry {$device}"

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
    device=$(get_device)
    [ -n "$device" ] && entry="$entry {$device}"

    log_entry "$entry"
fi
