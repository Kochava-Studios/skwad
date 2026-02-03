.PHONY: help build clean archive export notarize dmg release install increment-build appcast get-version get-build set-version prerelease latest

# Load .env file if it exists
-include .env
export

# Configuration
SCHEME := Skwad
APP_NAME := Skwad
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH := $(BUILD_DIR)/export
DMG_PATH := $(BUILD_DIR)/$(APP_NAME).dmg
ZIP_PATH := $(BUILD_DIR)/$(APP_NAME).zip
APPCAST_PATH := $(BUILD_DIR)/appcast.xml
CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# Download URL for updates
DOWNLOAD_URL ?= https://github.com/Kochava-Studios/skwad/releases/latest/download/Skwad.zip

# Apple Developer settings (override via environment variables)
TEAM_ID ?= $(shell /usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" ~/Library/Preferences/com.apple.dt.Xcode.plist 2>/dev/null)
APPLE_ID ?= $(shell /usr/libexec/PlistBuddy -c "Print :IDEKit:PreviousAccount" ~/Library/Preferences/com.apple.dt.Xcode.plist 2>/dev/null)
SIGNING_CERTIFICATE ?= Developer ID Application

# Default target: local build with signing and notarization
default: release

help:
	@echo "Skwad Build and Distribution Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make              - Local build with signing and notarization"
	@echo "  make prerelease   - Trigger GitHub Action build (prerelease)"
	@echo "  make latest       - Trigger GitHub Action build (latest release)"
	@echo ""
	@echo "Other targets:"
	@echo "  make build        - Build the app in Release configuration"
	@echo "  make archive      - Create an archive for distribution"
	@echo "  make export       - Export and sign the app (requires archive)"
	@echo "  make dmg          - Create a DMG (requires export)"
	@echo "  make zip          - Create a notarization-ready ZIP (requires export)"
	@echo "  make notarize     - Submit ZIP for notarization and staple"
	@echo "  make release      - Full release pipeline (increment build + notarize)"
	@echo "  make install      - Copy notarized app to /Applications"
	@echo "  make clean        - Clean build artifacts"
	@echo ""
	@echo "Environment variables (can be set in .env file):"
	@echo "  APPLE_ID              - Apple ID for notarization (current: $(APPLE_ID))"
	@echo "  TEAM_ID               - Team ID (current: $(TEAM_ID))"
	@echo "  APP_PASSWORD          - App-specific password for notarization"
	@echo "  SIGNING_CERTIFICATE   - Code signing certificate name (current: $(SIGNING_CERTIFICATE))"

build:
	@echo "Building $(APP_NAME)..."
	xcodebuild -scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		build

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

archive:
	@echo "Creating archive..."
	xcodebuild -scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		CODE_SIGN_IDENTITY="$(SIGNING_CERTIFICATE)" \
		CODE_SIGN_STYLE=Manual \
		clean archive
	@echo "Archive created at $(ARCHIVE_PATH)"

export: archive
	@echo "Exporting signed app..."
	@if [ -z "$(TEAM_ID)" ]; then \
		echo "Error: TEAM_ID not set"; \
		exit 1; \
	fi
	@mkdir -p $(EXPORT_PATH)
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(BUILD_DIR)/ExportOptions.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '<plist version="1.0">' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '<dict>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <key>method</key>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <string>developer-id</string>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <key>teamID</key>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <string>$(TEAM_ID)</string>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <key>signingStyle</key>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <string>automatic</string>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <key>signingCertificate</key>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '    <string>$(SIGNING_CERTIFICATE)</string>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '</dict>' >> $(BUILD_DIR)/ExportOptions.plist
	@echo '</plist>' >> $(BUILD_DIR)/ExportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(BUILD_DIR)/ExportOptions.plist \
		-allowProvisioningUpdates
	@echo "Signed app exported to $(EXPORT_PATH)"

dmg: export
	@echo "Creating DMG..."
	@if [ ! -d "$(EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "Error: App not found in export"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	@rm -f $(DMG_PATH)
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(EXPORT_PATH)/$(APP_NAME).app" \
		-ov -format UDZO \
		$(DMG_PATH)
	@echo "DMG created at $(DMG_PATH)"

zip: export
	@echo "Creating ZIP for notarization..."
	@if [ ! -d "$(EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "Error: App not found in export"; \
		exit 1; \
	fi
	@mkdir -p $(BUILD_DIR)
	@rm -f $(ZIP_PATH)
	cd "$(EXPORT_PATH)" && zip -r -y "../$(APP_NAME).zip" "$(APP_NAME).app"
	@echo "ZIP created at $(ZIP_PATH)"

notarize: zip
	@echo "Submitting for notarization..."
	@if [ -z "$(APPLE_ID)" ]; then \
		echo "Error: APPLE_ID not set"; \
		exit 1; \
	fi
	@if [ -z "$(TEAM_ID)" ]; then \
		echo "Error: TEAM_ID not set"; \
		exit 1; \
	fi
	@if [ -z "$(APP_PASSWORD)" ]; then \
		echo "Error: APP_PASSWORD not set. Create an app-specific password at appleid.apple.com"; \
		exit 1; \
	fi
	@echo "Uploading to Apple (this may take a few minutes)..."
	xcrun notarytool submit $(ZIP_PATH) \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--password "$(APP_PASSWORD)" \
		--wait
	@echo "Stapling notarization ticket to app..."
	xcrun stapler staple "$(EXPORT_PATH)/$(APP_NAME).app"
	@echo "Creating ZIP with stapled app..."
	@rm -f $(ZIP_PATH)
	cd "$(EXPORT_PATH)" && zip -r -y "../$(APP_NAME).zip" "$(APP_NAME).app"
	@echo "Creating DMG with stapled app..."
	@rm -f $(DMG_PATH)
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(EXPORT_PATH)/$(APP_NAME).app" \
		-ov -format UDZO \
		$(DMG_PATH)
	@echo "Generating appcast..."
	@./scripts/generate-appcast.sh "$(ZIP_PATH)" "$(EXPORT_PATH)/$(APP_NAME).app" "$(APPCAST_PATH)" "$(DOWNLOAD_URL)"
	@echo ""
	@echo "Notarization complete!"
	@echo "   App: $(EXPORT_PATH)/$(APP_NAME).app (stapled)"
	@echo "   ZIP: $(ZIP_PATH) (contains stapled app)"
	@echo "   DMG: $(DMG_PATH) (contains stapled app)"
	@echo "   Appcast: $(APPCAST_PATH)"

get-version:
	@grep -m1 "MARKETING_VERSION = " Skwad.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/'

get-build:
	@grep -m1 "CURRENT_PROJECT_VERSION = " Skwad.xcodeproj/project.pbxproj | sed 's/.*= \(.*\);/\1/'

set-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make set-version VERSION=x.y"; \
		exit 1; \
	fi
	@sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $(VERSION);/g" Skwad.xcodeproj/project.pbxproj
	@echo "Version set to $(VERSION)"

increment-build:
	@echo "Incrementing build number..."
	@./scripts/increment-build.sh

appcast:
	@echo "Generating appcast..."
	@./scripts/generate-appcast.sh "$(ZIP_PATH)" "$(EXPORT_PATH)/$(APP_NAME).app" "$(APPCAST_PATH)" "$(DOWNLOAD_URL)"

release: increment-build notarize
	@echo ""
	@echo "Release build complete!"
	@echo "   Distribution package: $(DMG_PATH)"
	@ls -lh $(DMG_PATH)

install:
	@echo "Installing $(APP_NAME).app to /Applications..."
	@if [ ! -d "$(EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "Error: Notarized app not found. Run 'make notarize' first."; \
		exit 1; \
	fi
	@echo "Removing existing installation..."
	@sudo rm -rf /Applications/$(APP_NAME).app
	@echo "Copying notarized app..."
	@sudo cp -R "$(EXPORT_PATH)/$(APP_NAME).app" /Applications/
	@echo "$(APP_NAME).app installed to /Applications"

# GitHub Actions release targets
prerelease:
	@git diff --quiet || (echo "Error: There are uncommitted changes. Commit or stash them first." && exit 1)
	@echo "Triggering GitHub Action for prerelease build..."
	gh workflow run build.yml --ref $(CURRENT_BRANCH) -f release_type=prerelease
	@echo "Workflow triggered. Monitor at: https://github.com/Kochava-Studios/skwad/actions"

latest:
	@git diff --quiet || (echo "Error: There are uncommitted changes. Commit or stash them first." && exit 1)
	@echo "Triggering GitHub Action for latest release build..."
	gh workflow run build.yml --ref $(CURRENT_BRANCH) -f release_type=latest
	@echo "Workflow triggered. Monitor at: https://github.com/Kochava-Studios/skwad/actions"
