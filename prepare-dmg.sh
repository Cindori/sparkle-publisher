#!/usr/bin/env bash

set -e  # Exit on any error

# Configuration
NAME="<Your App Name>"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/Build"
DMG_LAYOUT_FOLDER="$PROJECT_ROOT/DMG"
NOTARY_PROFILE="notarytool"
DEVELOPER_ID="<Your Developer ID>"

echo "🔍 Searching for builds..." >&2
AVAILABLE_BUILDS=()
while IFS= read -r line; do
    AVAILABLE_BUILDS+=("$line")
done < <(find "$BUILD_DIR" -maxdepth 1 -type d -exec stat -f "%m %N" {} \; | sort -nr | cut -d' ' -f2-)

if [[ ${#AVAILABLE_BUILDS[@]} -eq 0 ]]; then
    echo "❌ No builds found in $BUILD_DIR!"
    exit 1
fi

# Extract only folder names, preserving spaces
BUILD_NAMES=()
for dir in "${AVAILABLE_BUILDS[@]}"; do
    BUILD_NAMES+=("$(basename "$dir")")
done

# Use fzf for selection if available
if command -v fzf &>/dev/null; then
    echo "↕️ Select a build using arrow keys:" >&2
    SELECTED_BUILD_NAME=$(printf "%s\n" "${BUILD_NAMES[@]}" | fzf --height=10 --reverse)
else
    echo "↕️ Available builds:" >&2
    for i in "${!BUILD_NAMES[@]}"; do
        echo "$((i+1))) ${BUILD_NAMES[$i]}" >&2
    done

    read -p "Select a build (default: latest): " BUILD_SELECTION >&2
    if [[ -z "$BUILD_SELECTION" || ! "$BUILD_SELECTION" =~ ^[0-9]+$ || "$BUILD_SELECTION" -lt 1 || "$BUILD_SELECTION" -gt ${#BUILD_NAMES[@]} ]]; then
        SELECTED_BUILD_NAME="${BUILD_NAMES[0]}"  # Default to latest
    else
        SELECTED_BUILD_NAME="${BUILD_NAMES[$((BUILD_SELECTION-1))]}"
    fi
fi

SELECTED_BUILD_DIR="$BUILD_DIR/$SELECTED_BUILD_NAME"
APP_BUNDLE="$SELECTED_BUILD_DIR/$NAME.app"
DMG_FILE="${APP_BUNDLE%.app}.dmg"

echo "✅ Selected build: $SELECTED_BUILD_NAME" >&2

# Check if DMG already exists
if [[ -f "$DMG_FILE" ]]; then
    echo "⚠️ A DMG file already exists: $DMG_FILE" >&2
    echo -n "Do you want to delete it and create a new one? (y/n)? " >&2
    read answer
    if [[ "$answer" != "${answer#[Nn]}" ]]; then
        echo "❌ Aborting. Existing DMG not deleted." >&2
        exit 1
    fi
    echo "🗑️ Deleting existing DMG..." >&2
    rm "$DMG_FILE"
fi

# Extract version and build number
VERSION=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleShortVersionString)
BUILD=$(defaults read "$APP_BUNDLE/Contents/Info.plist" CFBundleVersion)

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    echo "❌ Failed to extract version or build number!" >&2
    exit 1
fi

echo "📦 Building DMG..." >&2
/usr/local/bin/dropdmg --signing-identity "$DEVELOPER_ID" --layout-folder "$DMG_LAYOUT_FOLDER" --format lzma "$APP_BUNDLE" >&2

# Notarization
echo "✍️ Uploading DMG for notarization..." >&2
/usr/bin/xcrun notarytool submit "$DMG_FILE" --keychain-profile "$NOTARY_PROFILE" --wait >&2
echo "📝 Notarization complete!" >&2

echo "🧷 Stapling..." >&2
/usr/bin/xcrun stapler staple "$DMG_FILE" >&2
echo "🎁 DMG is ready for publishing." >&2

# 🚀 **Final output: ONLY the DMG path**
echo "$DMG_FILE"
