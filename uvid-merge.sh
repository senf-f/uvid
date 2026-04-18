#!/bin/bash
# Merges incoming uvid log files with canonical copies.
# Usage: ./uvid-merge.sh <incoming-dir>
# Canonical logs live in the same directory as this script.

set -e

CANONICAL_DIR="$(cd "$(dirname "$0")" && pwd)"
INCOMING_DIR="$1"

if [ -z "$INCOMING_DIR" ] || [ ! -d "$INCOMING_DIR" ]; then
    echo "Usage: $0 <incoming-dir>"
    exit 1
fi

for incoming_file in "$INCOMING_DIR"/*_uvid.log; do
    [ -f "$incoming_file" ] || continue

    filename="$(basename "$incoming_file")"
    canonical_file="$CANONICAL_DIR/$filename"

    if [ ! -f "$canonical_file" ]; then
        cp "$incoming_file" "$canonical_file"
        continue
    fi

    # Merge: concat both, sort by timestamp, deduplicate exact lines
    tmpfile=$(mktemp)
    cat "$canonical_file" "$incoming_file" | sort -t']' -k1,1 | uniq > "$tmpfile"
    mv "$tmpfile" "$canonical_file"
done
