#!/bin/bash
# Syncs local uvid logs with VPS.
# Pushes local logs, runs merge on VPS, pulls merged result back.
#
# Config: set VPS_HOST before use.
# Usage: ./uvid-sync.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="${UVID_DIR:-$HOME/.uvid}"

# Defaults — override via .uvid-sync.conf (gitignored) or env vars
VPS_HOST=""
VPS_USER="root"
VPS_DIR="~/uvid-logs"

[ -f "$SCRIPT_DIR/.uvid-sync.conf" ] && source "$SCRIPT_DIR/.uvid-sync.conf"

if [ -z "$VPS_HOST" ]; then
    echo "VPS_HOST is not set. Create $SCRIPT_DIR/.uvid-sync.conf with:"
    echo "  VPS_HOST=\"your-host-or-alias\""
    exit 1
fi

DRY_RUN=""
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[dry-run] No files will be changed."
fi

# Prefer rsync (skips unchanged files); fall back to scp if unavailable.
if command -v rsync >/dev/null 2>&1; then
    HAVE_RSYNC=true
else
    HAVE_RSYNC=""
    echo "Warning: rsync not found, falling back to scp (all files will be copied)."
fi

# Step 1: Push local logs to a staging directory on VPS
echo "Pushing local logs to VPS..."
ssh "$VPS_USER@$VPS_HOST" "mkdir -p $VPS_DIR/incoming"

if [ -n "$DRY_RUN" ]; then
    if [ -n "$HAVE_RSYNC" ]; then
        echo "Would transfer (unchanged files skipped):"
        rsync -az --dry-run "$LOCAL_DIR"/*_uvid.log "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"
    else
        echo "Would copy:"
        ls "$LOCAL_DIR"/*_uvid.log 2>/dev/null
    fi
    echo "[dry-run] Would merge on VPS and pull back."
    exit 0
fi

if [ -n "$HAVE_RSYNC" ]; then
    rsync -az "$LOCAL_DIR"/*_uvid.log "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"
else
    scp "$LOCAL_DIR"/*_uvid.log "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"
fi

# Step 2: Run merge on VPS
echo "Merging on VPS..."
ssh "$VPS_USER@$VPS_HOST" "bash $VPS_DIR/uvid-merge.sh $VPS_DIR/incoming"

# Step 3: Clean up incoming on VPS
ssh "$VPS_USER@$VPS_HOST" "rm -f $VPS_DIR/incoming/*_uvid.log"

# Step 4: Pull merged logs back
echo "Pulling merged logs..."
if [ -n "$HAVE_RSYNC" ]; then
    rsync -az "$VPS_USER@$VPS_HOST:$VPS_DIR"/*_uvid.log "$LOCAL_DIR/"
else
    scp "$VPS_USER@$VPS_HOST:$VPS_DIR"/*_uvid.log "$LOCAL_DIR/"
fi

echo "Sync complete."
