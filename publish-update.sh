#!/usr/bin/env bash

set -e  # Exit on any error

# Configuration
NAME="<Your App Name>"
NAME_LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')  # macOS-compatible lowercase conversion
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANGELOG="$PROJECT_ROOT/Changelog.md"
S3_BUCKET="s3://<Your Bucket>"
S3_BASE_URL="<Your CDN Base URL>"
WEBSITE="<Your App Website>"
SIGN_UPDATE_TOOL="$PROJECT_ROOT/Utilities/Sparkle/sign_update"
GENERATE_APPCAST_TOOL="$PROJECT_ROOT/Utilities/Sparkle/generate_appcast"
CLOUDFRONT_DISTRIBUTION_ID="<Your CloudFront Distribution ID>"

# Check if DMG is provided
if [[ -z "$1" ]]; then
    echo "❌ No DMG file provided!"
    echo "Usage: ./publish-update.sh /path/to/dmg"
    exit 1
fi

DMG_FILE="$(realpath "$1")"  # Ensure absolute path
UPDATE_DIR="$(dirname "$DMG_FILE")"  # Use DMG's directory for appcast
PARTIAL_APPCAST_FILE="$UPDATE_DIR/partial_update.xml"
APPCAST_FILE="$UPDATE_DIR/update.xml"
EXISTING_APPCAST_FILE="$UPDATE_DIR/existing_update.xml"

# Generate `update.xml` using local DMG instead of reading from S3
echo "📝 Generating Sparkle appcast..."
"$GENERATE_APPCAST_TOOL" --link "$WEBSITE" -o "$PARTIAL_APPCAST_FILE" "$UPDATE_DIR"

# Extract version & build using awk (compatible with macOS)
VERSION=$(awk -F '[<>]' '/<sparkle:shortVersionString>/ {print $3}' "$PARTIAL_APPCAST_FILE")
BUILD=$(awk -F '[<>]' '/<sparkle:version>/ {print $3}' "$PARTIAL_APPCAST_FILE")

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    echo "❌ Failed to extract version or build from appcast!"
    exit 1
fi

echo "🏷️ Extracted version: $VERSION, build: $BUILD"

# Define paths
S3_UPDATE_PATH="apps/${NAME_LOWER}/updates/$VERSION-$BUILD/${NAME}.dmg"
S3_LATEST_PATH="apps/${NAME_LOWER}/${NAME}.dmg"
S3_APPCAST_PATH="apps/${NAME_LOWER}/updates/update.xml"
CORRECT_URL="$S3_BASE_URL/$S3_UPDATE_PATH"

# 🔍 Extract changelog for this version (INCLUDING title)
CHANGELOG_CONTENT=$(awk -v version="$VERSION" -v build="$BUILD" '
    BEGIN {found=0}
    $0 ~ "^## " version " \\(" build "\\) " {found=1}  # Start capturing from title
    found && /^## / && !($0 ~ "^## " version " \\(" build "\\) ") {exit}  # Stop at next title
    found {print}
' "$CHANGELOG")

if [[ -z "$CHANGELOG_CONTENT" ]]; then
    echo "⚠️ No changelog entry found for version $VERSION (Build $BUILD)."
    exit 1
fi

# Convert changelog to HTML
CHANGELOG_HTML=$(echo "$CHANGELOG_CONTENT" | pandoc -f markdown-auto_identifiers -t html | sed 's/"/\&quot;/g')

# Wrap the HTML in a <div>
FULL_CHANGELOG_HTML=$(cat <<EOF
<div>
    $CHANGELOG_HTML
</div>
EOF
)

# Show preview in plain text
echo "🔎 Changelog Preview (Plain Text):"
echo "---------------------------------------------------------"
echo "$CHANGELOG_CONTENT"
echo "---------------------------------------------------------"

# Show preview in HTML format
#echo "🔎 Changelog Preview (HTML Format):"
#echo "---------------------------------------------------------"
#echo "$CHANGELOG_HTML"
#echo "---------------------------------------------------------"

# Ask for confirmation before proceeding
echo -n "Proceed with creating update (y/n)? "
read answer
if [[ "$answer" != "${answer#[Nn]}" ]]; then
    echo "❌ Update canceled."
    exit 1
fi

# Wrap the HTML in a <div>
FULL_CHANGELOG_HTML=$(cat <<EOF
<div>
    $CHANGELOG_HTML
</div>
EOF
)

# Check if an existing update.xml exists
if aws s3 ls "$S3_BUCKET/$S3_APPCAST_PATH" > /dev/null 2>&1; then
    echo "📡 Found existing update.xml. Downloading..."
    aws s3 cp "$S3_BUCKET/$S3_APPCAST_PATH" "$EXISTING_APPCAST_FILE"
    APPCAST_EXISTS=true
    # 🚨 Check if this version already exists
    if grep -q "<sparkle:version>$BUILD</sparkle:shortVersionString>" "$EXISTING_APPCAST_FILE"; then
        echo "❌ Build $BUILD already exists in update.xml!"
        echo "⚠️ Aborting to prevent duplicate versions."
        exit 1
    fi
else
    echo "⚠️ No existing update.xml found. Using new appcast only."
    APPCAST_EXISTS=false
fi

# Merge old appcast (if exists) or use the new one
if [[ "$APPCAST_EXISTS" == true ]]; then
    echo "🔄 Merging new update into existing appcast..."

    # Copy everything up to <channel> (keep header and opening tag)
    awk '/<channel>/ {print; exit} {print}' "$EXISTING_APPCAST_FILE" > "$APPCAST_FILE"

    # Insert the new update entry at the top (newest version first)
    awk '/<item>/,/<\/item>/' "$PARTIAL_APPCAST_FILE" >> "$APPCAST_FILE"

    # Append all existing <item> entries (preserving version history)
    awk '/<item>/,/<\/item>/' "$EXISTING_APPCAST_FILE" >> "$APPCAST_FILE"

    # Close the channel properly
    echo "</channel></rss>" >> "$APPCAST_FILE"

else
    echo "✅ Using new appcast as the final update.xml (no existing history)."
    cp "$PARTIAL_APPCAST_FILE" "$APPCAST_FILE"
fi

# Inject changelog into `update.xml`
perl -i -pe "s{</item>}{<description><![CDATA[$FULL_CHANGELOG_HTML]]></description>\n</item>}g" "$APPCAST_FILE"

# Replace incorrect enclosure URL with the correct one
perl -i -pe "s{<enclosure url=\"[^\"]*\"}{<enclosure url=\"$CORRECT_URL\"}g" "$APPCAST_FILE"

# Show preview of `update.xml`
#echo "🔎 Appcast Preview:"
#echo "---------------------------------------------------------"
#cat "$APPCAST_FILE"
#echo "---------------------------------------------------------"

# Ask for final confirmation before uploading
echo -n "Proceed with uploading the update to S3? (y/n)? "
read answer
if [[ "$answer" != "${answer#[Nn]}" ]]; then
    echo "❌ Upload canceled."
    exit 1
fi

# Upload DMG to S3
echo "☁️ Uploading release to S3..."
aws s3 cp "$DMG_FILE" "$S3_BUCKET/$S3_UPDATE_PATH"
aws s3 cp "$APPCAST_FILE" "$S3_BUCKET/$S3_APPCAST_PATH"
# Copy the remote DMG to release path instead of re-uploading
aws s3 cp "$S3_BUCKET/$S3_UPDATE_PATH" "$S3_BUCKET/$S3_LATEST_PATH"

aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/$S3_UPDATE_PATH" "/$S3_LATEST_PATH" "/$S3_APPCAST_PATH"

echo "🎉 Done. Release is now live!"
