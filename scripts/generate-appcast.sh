#!/bin/bash
# generate-appcast.sh
# Generates Sparkle appcast.xml for auto-update with EdDSA signature

set -e

# Parameters
ZIP_PATH="${1:-build/Skwad.zip}"
APP_PATH="${2:-build/export/Skwad.app}"
OUTPUT_PATH="${3:-build/appcast.xml}"
DOWNLOAD_URL="${4:-https://github.com/Kochava-Studios/skwad/releases/latest/download/Skwad.zip}"

# Sparkle sign_update tool location - search common paths
SIGN_TOOL=$(find build/DerivedData .build ~/Library/Developer/Xcode/DerivedData -name "sign_update" -path "*/sparkle/Sparkle/bin/*" 2>/dev/null | head -1)

# Validate inputs
if [ ! -f "$ZIP_PATH" ]; then
    echo "Error: ZIP file not found: $ZIP_PATH"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found: $APP_PATH"
    exit 1
fi

# Extract version info from app
INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST" 2>/dev/null || echo "14.0")

# Get file size
FILE_SIZE=$(stat -f%z "$ZIP_PATH")

# Get EdDSA signature
if [ -n "$SIGN_TOOL" ] && [ -f "$SIGN_TOOL" ]; then
    echo "Signing ZIP with EdDSA..."
    SIGNATURE=$("$SIGN_TOOL" "$ZIP_PATH" 2>/dev/null | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
    if [ -z "$SIGNATURE" ]; then
        echo "Warning: Could not generate signature. Is the private key in Keychain?"
        SIGNATURE=""
    fi
else
    echo "Warning: sign_update tool not found. Run 'make build' first."
    SIGNATURE=""
fi

# Get current date in RFC 822 format
PUB_DATE=$(date -R)

echo "Generating appcast.xml..."
echo "  Version: $VERSION (build $BUILD)"
echo "  Size: $FILE_SIZE bytes"
echo "  Signature: ${SIGNATURE:0:20}..."
echo "  Min macOS: $MIN_OS"

# Generate appcast.xml
cat > "$OUTPUT_PATH" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Skwad Updates</title>
    <link>https://github.com/Kochava-Studios/skwad/releases/latest/download/appcast.xml</link>
    <description>Most recent changes with links to updates.</description>
    <language>en</language>
    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <enclosure url="$DOWNLOAD_URL"
                 sparkle:edSignature="$SIGNATURE"
                 length="$FILE_SIZE"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Appcast generated: $OUTPUT_PATH"
