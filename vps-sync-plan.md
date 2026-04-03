# VPS Log Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periodically sync uvid log files between two machines via a VPS, merging entries from both without data loss.

**Architecture:** Each machine runs a cron job (`uvid-sync.sh`) every 15 minutes. The script pushes local logs to the VPS via rsync, runs a merge script on the VPS that deduplicates and sorts by timestamp, then pulls the merged result back. The VPS at `~/uvid-logs/` is the canonical source of truth.

**Tech Stack:** Bash, rsync, ssh, cron. No external dependencies.

---

## File Structure

| File | Location | Responsibility |
|------|----------|----------------|
| `uvid-sync.sh` | Each machine (in the uvid repo dir) | Push local logs, trigger merge, pull merged result |
| `uvid-merge.sh` | VPS at `~/uvid-logs/uvid-merge.sh` | Merge incoming logs with canonical copies: concat, sort by timestamp, deduplicate |

## Prerequisites

- SSH key access to VPS as root (already confirmed)
- rsync installed on both machines and VPS
- Replace `VPS_HOST` in the scripts with the actual VPS hostname/IP

---

### Task 1: Create the merge script (runs on VPS)

**Files:**
- Create: `uvid-merge.sh` (will be deployed to VPS at `~/uvid-logs/uvid-merge.sh`)

- [ ] **Step 1: Create `uvid-merge.sh`**

This script lives on the VPS. It takes a directory of incoming log files and merges them with the canonical copies.

```bash
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
```

- [ ] **Step 2: Test merge logic locally before deploying**

Create two test files and verify merge works:

```bash
# Simulate canonical file
echo "[01.04.2026 10:00] entry from machine A [.] (-)" > /tmp/canonical_2026_uvid.log
echo "[01.04.2026 12:00] shared entry [.] (-)" >> /tmp/canonical_2026_uvid.log

# Simulate incoming file
echo "[01.04.2026 11:00] entry from machine B [.] (-)" > /tmp/incoming_2026_uvid.log
echo "[01.04.2026 12:00] shared entry [.] (-)" >> /tmp/incoming_2026_uvid.log

# Simulate merge
cat /tmp/canonical_2026_uvid.log /tmp/incoming_2026_uvid.log | sort -t']' -k1,1 | uniq
```

Expected output (3 lines, sorted, no duplicate):
```
[01.04.2026 10:00] entry from machine A [.] (-)
[01.04.2026 11:00] entry from machine B [.] (-)
[01.04.2026 12:00] shared entry [.] (-)
```

- [ ] **Step 3: Commit**

```bash
git add uvid-merge.sh
git -c user.email=mate.mrse@gmail.com commit -m "Add merge script for VPS log sync"
```

---

### Task 2: Create the sync script (runs on each machine)

**Files:**
- Create: `uvid-sync.sh`

- [ ] **Step 1: Create `uvid-sync.sh`**

```bash
#!/bin/bash
# Syncs local uvid logs with VPS.
# Pushes local logs, runs merge on VPS, pulls merged result back.
#
# Config: set VPS_HOST before use.
# Usage: ./uvid-sync.sh [--dry-run]

set -e

VPS_HOST="VPS_HOST"
VPS_USER="root"
VPS_DIR="~/uvid-logs"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=""
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo "[dry-run] No files will be changed."
fi

# Step 1: Push local logs to a staging directory on VPS
echo "Pushing local logs to VPS..."
ssh "$VPS_USER@$VPS_HOST" "mkdir -p $VPS_DIR/incoming"
rsync $DRY_RUN -avz --include='*_uvid.log' --exclude='*' "$LOCAL_DIR/" "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"

if [ -n "$DRY_RUN" ]; then
    echo "[dry-run] Would merge on VPS and pull back."
    exit 0
fi

# Step 2: Run merge on VPS
echo "Merging on VPS..."
ssh "$VPS_USER@$VPS_HOST" "bash $VPS_DIR/uvid-merge.sh $VPS_DIR/incoming"

# Step 3: Clean up incoming on VPS
ssh "$VPS_USER@$VPS_HOST" "rm -f $VPS_DIR/incoming/*_uvid.log"

# Step 4: Pull merged logs back
echo "Pulling merged logs..."
rsync -avz --include='*_uvid.log' --exclude='*' "$VPS_USER@$VPS_HOST:$VPS_DIR/" "$LOCAL_DIR/"

echo "Sync complete."
```

- [ ] **Step 2: Make executable**

```bash
chmod +x uvid-sync.sh
```

- [ ] **Step 3: Test with --dry-run**

```bash
./uvid-sync.sh --dry-run
```

Expected: shows what would be transferred, no actual changes.

- [ ] **Step 4: Commit**

```bash
git add uvid-sync.sh
git -c user.email=mate.mrse@gmail.com commit -m "Add sync script for VPS log backup"
```

---

### Task 3: Deploy merge script to VPS

- [ ] **Step 1: Create the directory and copy the merge script**

```bash
ssh root@VPS_HOST "mkdir -p ~/uvid-logs"
scp uvid-merge.sh root@VPS_HOST:~/uvid-logs/uvid-merge.sh
ssh root@VPS_HOST "chmod +x ~/uvid-logs/uvid-merge.sh"
```

- [ ] **Step 2: Run a full sync to seed VPS with current logs**

```bash
./uvid-sync.sh
```

Expected: logs are pushed, merged (first run just copies), and pulled back. Local files should be unchanged.

- [ ] **Step 3: Verify VPS has the files**

```bash
ssh root@VPS_HOST "ls -la ~/uvid-logs/*_uvid.log"
```

Expected: `2023_uvid.log`, `2024_uvid.log`, `2026_uvid.log` present.

---

### Task 4: Set up cron on each machine

- [ ] **Step 1: Add cron job on the Windows machine (via WSL or Git Bash)**

```bash
(crontab -l 2>/dev/null; echo "*/15 * * * * /c/Users/mate.mrse/privatno/moji-projekti/uvid/uvid-sync.sh >> /tmp/uvid-sync.log 2>&1") | crontab -
```

Verify:
```bash
crontab -l
```

Expected: line with `*/15 * * * *` and the path to `uvid-sync.sh`.

- [ ] **Step 2: Add cron job on the second machine**

Same pattern — adjust the path to wherever the uvid repo is cloned:

```bash
(crontab -l 2>/dev/null; echo "*/15 * * * * /path/to/uvid/uvid-sync.sh >> /tmp/uvid-sync.log 2>&1") | crontab -
```

- [ ] **Step 3: Test the cron works**

Wait 15 minutes, then check:

```bash
cat /tmp/uvid-sync.log
```

Expected: sync output showing push/merge/pull with no errors.

---

### Task 5: Add `--sync` flag to uvid.sh

**Files:**
- Modify: `uvid.sh`

- [ ] **Step 1: Add `--sync` to the case statement**

After the `--delete` case, add:

```bash
    --sync)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -x "$SCRIPT_DIR/uvid-sync.sh" ]; then
            "$SCRIPT_DIR/uvid-sync.sh"
        else
            echo "uvid-sync.sh not found or not executable."
            exit 1
        fi
        exit 0 ;;
```

- [ ] **Step 2: Add to help text**

After the `--delete` help line, add:

```bash
    echo "  --sync            Sync logs with VPS"
```

- [ ] **Step 3: Commit**

```bash
git add uvid.sh
git -c user.email=mate.mrse@gmail.com commit -m "Add --sync flag to trigger VPS log sync"
```

---

### Task 6: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Sync section after Delete section**

```markdown
### Sync logs with VPS
```bash
uvid --sync
```
Manually trigger a sync with the VPS. Pushes local logs, merges with remote, pulls merged result. Also runs automatically every 15 minutes via cron.

**Setup:**
1. Set `VPS_HOST` in `uvid-sync.sh`
2. Deploy merge script: `scp uvid-merge.sh root@VPS_HOST:~/uvid-logs/`
3. Run first sync: `uvid --sync`
4. Add cron: `*/15 * * * * /path/to/uvid/uvid-sync.sh >> /tmp/uvid-sync.log 2>&1`
```

- [ ] **Step 2: Add to Options table**

```markdown
| `--sync` | Sync logs with VPS |
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git -c user.email=mate.mrse@gmail.com commit -m "Document VPS sync in README"
```
