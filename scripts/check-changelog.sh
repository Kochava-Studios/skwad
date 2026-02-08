#!/bin/bash
# check-changelog.sh
# Validates that CHANGELOG.md has a proper entry for the version being released

set -e

# Get version from project
VERSION=$(grep -m1 "MARKETING_VERSION = " Skwad.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/')

if [ -z "$VERSION" ]; then
    echo "Error: Could not determine version from project"
    exit 1
fi

echo "Checking changelog for version $VERSION..."

# Check that a section exists for this version
if ! grep -q "## \[$VERSION\]" CHANGELOG.md; then
    echo "Error: No changelog entry found for version $VERSION"
    echo "  Add a '## [$VERSION]' section to CHANGELOG.md before releasing"
    exit 1
fi

# Check that the entry is not WIP
DATE=$(grep "## \[$VERSION\]" CHANGELOG.md | sed 's/.*- \(.*\)/\1/')
if echo "$DATE" | grep -qi "WIP"; then
    echo "Error: Changelog entry for version $VERSION is still marked as WIP"
    echo "  Update the date in '## [$VERSION] - WIP' before releasing"
    exit 1
fi

echo "Changelog OK: version $VERSION dated $DATE"
