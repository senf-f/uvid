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
            if (match(line, /^\[[^\]]+\]/)) {
                return substr(line, RSTART, RLENGTH)
            }
            return ""
        }
        function device(line) {
            if (match(line, /\{[a-z0-9-]+\}$/)) {
                return substr(line, RSTART, RLENGTH)
            }
            return ""
        }
        function dedup_key(line) {
            t = ts(line)
            d = device(line)
            if (d != "") {
                return t SUBSEP d
            }
            return ""
        }
        FNR == NR {
            # Pass 1: incoming
            inc_order[++inc_n] = $0
            k = dedup_key($0)
            if (k != "") {
                inc_by_key[k] = $0
                inc_has_key[k] = 1
            }
            inc_full[$0] = 1
            next
        }
        # Pass 2: canonical
        {
            k = dedup_key($0)
            if (k != "" && (k in inc_has_key)) {
                # Same timestamp+device: incoming wins (edit propagation)
                if (!(k in printed)) {
                    print inc_by_key[k]
                    printed[k] = 1
                }
            } else if (k != "") {
                # Has device but not in incoming — keep canonical
                if (!(k in can_seen)) {
                    print
                    can_seen[k] = 1
                }
            } else {
                # No device tag — dedup by full line
                if (!($0 in full_seen)) {
                    print
                    full_seen[$0] = 1
                }
            }
        }
        END {
            for (i = 1; i <= inc_n; i++) {
                line = inc_order[i]
                k = dedup_key(line)
                if (k != "") {
                    if (!(k in printed)) {
                        print line
                        printed[k] = 1
                    }
                } else {
                    # No device — append only if not already output
                    if (!(line in full_seen)) {
                        print line
                        full_seen[line] = 1
                    }
                }
            }
        }
    ' "$incoming_file" "$canonical_file" > "$tmpfile"
    mv "$tmpfile" "$canonical_file"
done
