#!/bin/bash
# Merges incoming uvid log files with canonical copies.
#
# Strategy:
#   - Union of entries, identified by timestamp (the [DD.MM.YYYY HH:MM] prefix).
#   - If the same timestamp exists in both canonical and incoming, the
#     incoming version wins (so edits propagate across machines).
#   - Original insertion order is preserved (no sorting).
#   - New incoming entries (timestamps not in canonical) are appended at the end.
#
# Limitation: deletes do NOT propagate across machines. An entry deleted on one
# machine will come back on the next sync unless deleted on all machines.
#
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

    tmpfile=$(mktemp)
    awk '
        function ts(line) {
            if (match(line, /^\[[^]]+\]/)) {
                return substr(line, RSTART, RLENGTH)
            }
            return ""
        }
        FNR == NR {
            # Pass 1: incoming
            t = ts($0)
            inc_order[++inc_n] = $0
            inc_ts[inc_n] = t
            if (t != "") inc_by_ts[t] = $0
            next
        }
        # Pass 2: canonical
        {
            t = ts($0)
            if (t != "" && (t in inc_by_ts)) {
                if (!(t in printed)) {
                    print inc_by_ts[t]
                    printed[t] = 1
                }
            } else if (t != "") {
                if (!(t in can_seen)) {
                    print
                    can_seen[t] = 1
                }
            } else {
                print
            }
        }
        END {
            for (i = 1; i <= inc_n; i++) {
                t = inc_ts[i]
                if (t == "") {
                    print inc_order[i]
                } else if (!(t in printed)) {
                    print inc_order[i]
                    printed[t] = 1
                }
            }
        }
    ' "$incoming_file" "$canonical_file" > "$tmpfile"
    mv "$tmpfile" "$canonical_file"
done
