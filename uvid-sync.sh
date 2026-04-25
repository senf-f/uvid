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
    DRY_RUN="--dry-run"
    echo "[dry-run] No files will be changed."
fi

if [ -n "$DRY_RUN" ]; then
    echo "Pushing local logs to VPS (dry-run)..."
    rsync $DRY_RUN -avz --include='*_uvid.log' --exclude='*' "$LOCAL_DIR/" "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"
    echo "[dry-run] Would merge on VPS and pull back."
    exit 0
fi

# Step 1: Push local logs to a staging directory on VPS
echo "Pushing local logs to VPS..."
ssh "$VPS_USER@$VPS_HOST" "mkdir -p $VPS_DIR/incoming"
rsync -avz --include='*_uvid.log' --exclude='*' "$LOCAL_DIR/" "$VPS_USER@$VPS_HOST:$VPS_DIR/incoming/"

# Step 2: Run merge on VPS
echo "Merging on VPS..."
ssh "$VPS_USER@$VPS_HOST" "bash $VPS_DIR/uvid-merge.sh $VPS_DIR/incoming"

# Step 3: Clean up incoming on VPS
ssh "$VPS_USER@$VPS_HOST" "rm -f $VPS_DIR/incoming/*_uvid.log"

# Step 4: Pull merged logs back
echo "Pulling merged logs..."
rsync -avz --include='*_uvid.log' --exclude='*' "$VPS_USER@$VPS_HOST:$VPS_DIR/" "$LOCAL_DIR/"

echo "Sync complete."
