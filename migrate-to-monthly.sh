#!/bin/bash
# Migrates yearly YYYY_uvid.log files to monthly MM-YYYY_uvid.log files.
# Entries are distributed based on their timestamp [DD.MM.YYYY HH:MM].
# Run from the uvid log directory, or pass the directory as an argument.
#
# Usage: bash migrate-to-monthly.sh [UVID_DIR]

UVID_DIR="${1:-${UVID_DIR:-$HOME/.uvid}}"

if [ ! -d "$UVID_DIR" ]; then
    echo "Directory not found: $UVID_DIR"
    exit 1
fi

shopt -s nullglob
yearly_files=("$UVID_DIR"/[0-9][0-9][0-9][0-9]_uvid.log)

if [ ${#yearly_files[@]} -eq 0 ]; then
    echo "No yearly log files found in $UVID_DIR"
    exit 0
fi

for file in "${yearly_files[@]}"; do
    filename=$(basename "$file")
    echo "Processing $filename..."
    count=0

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        if [[ "$line" =~ ^\[([0-9]{2})\.([0-9]{2})\.([0-9]{4}) ]]; then
            month="${BASH_REMATCH[2]}"
            year="${BASH_REMATCH[3]}"
            target="$UVID_DIR/${month}-${year}_uvid.log"
            echo "$line" >> "$target"
            ((count++))
        else
            echo "  WARN: skipping unrecognized line: $line"
        fi
    done < "$file"

    echo "  Migrated $count entries"

    # Rename original as backup
    mv "$file" "${file}.bak"
    echo "  Backed up original to ${filename}.bak"
done

echo ""
echo "Migration complete. Verify results, then remove .bak files:"
echo "  rm $UVID_DIR/*_uvid.log.bak"
