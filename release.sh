#!/usr/bin/env bash

set -e  # Exit on any error

# Configuration
SCRIPT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PREPARE_DMG_SCRIPT="$SCRIPT_ROOT/prepare-dmg.sh"
PUBLISH_UPDATE_SCRIPT="$SCRIPT_ROOT/publish-update.sh"

echo "🛠 Starting Release Process"

# Step 1: Run prepare-dmg.sh and capture the DMG path (ONLY the path, no logs)
DMG_FILE=$("$PREPARE_DMG_SCRIPT")

if [[ -z "$DMG_FILE" || ! -f "$DMG_FILE" ]]; then
    echo "❌ No DMG file found after preparation!"
    exit 1
fi

# Step 2: Run publish-update.sh to issue the update
"$PUBLISH_UPDATE_SCRIPT" "$DMG_FILE"
