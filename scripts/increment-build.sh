#!/bin/bash
# increment-build.sh
# Increments CURRENT_PROJECT_VERSION in the Xcode project

set -e

PROJECT_FILE="Skwad.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: $PROJECT_FILE not found"
    exit 1
fi

# Get current build number (find first occurrence)
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | sed 's/.*= \([0-9]*\);/\1/')

if [ -z "$CURRENT_BUILD" ]; then
    echo "Error: Could not find CURRENT_PROJECT_VERSION in $PROJECT_FILE"
    exit 1
fi

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update all occurrences in project file
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

echo "Build number incremented: $CURRENT_BUILD -> $NEW_BUILD"

# Commit the change
git add "$PROJECT_FILE"
git commit -m "chore: increment build number"
