# Sparkle Auto-Update Implementation Plan

## Overview

Implement automatic update functionality using Sparkle 2.x framework, integrated with the existing Makefile release pipeline.

## Goals

1. Integrate Sparkle framework into Skwad
2. Add `make release` target to auto-increment build number
3. Add `make upload` target to:
   - Upload the notarized ZIP to the server
   - Generate and upload appcast.xml for Sparkle

## Implementation Strategy

Work incrementally, testing at each phase, with frequent commits. The plan follows a dependency-first approach: setup → integration → build automation → upload automation.

## Phase 1: Sparkle Framework Integration ✅ COMPLETED

**Goal**: Get Sparkle integrated and app checking for updates (even if feed doesn't exist yet)

### Tasks

1. ✅ **Add Sparkle via SPM**
   - Add Sparkle 2.x as SPM dependency in Package.swift and project.pbxproj
   - Verify it builds successfully
   - Commit: `feat: add sparkle framework dependency`

2. ✅ **Create UpdaterManager**
   - Create `Skwad/Updater/UpdaterManager.swift`
   - Singleton that wraps SPUStandardUpdaterController
   - CheckForUpdatesView for menu integration
   - Add Info.plist with SUFeedURL
   - Commit: `feat: add updater manager wrapper`

3. ✅ **Integrate into App Lifecycle**
   - Update `SkwadApp.swift` to initialize UpdaterManager
   - Add "Check for Updates" menu item to app menu using .commands
   - Commit: `feat: integrate updater into app lifecycle`

4. ✅ **Add Settings**
   - Add auto-update toggle to GeneralSettingsView
   - Uses Sparkle's built-in automaticallyChecksForUpdates property
   - Commit: `feat: add update settings`

## Phase 2: Build Number Automation ✅ COMPLETED

**Goal**: Automate version numbering in the release process

### Tasks

1. ✅ **Create version increment script**
   - Create `scripts/increment-build.sh`
   - Uses sed to read and update CURRENT_PROJECT_VERSION
   - Increments by 1, updates both Debug and Release configs
   - Commit: `feat: add build number increment script`

2. ✅ **Update Makefile release target**
   - Add `increment-build` target
   - Make `release` depend on `increment-build` before `notarize`
   - Commit: `feat: auto-increment build on release`

## Phase 3: Appcast Generation ✅ COMPLETED

**Goal**: Generate Sparkle-compatible appcast.xml with release metadata

### Tasks

1. ✅ **Create appcast generation script**
   - Create `scripts/generate-appcast.sh`
   - Parameters: ZIP_PATH, APP_PATH, OUTPUT_PATH, DOWNLOAD_URL
   - Extracts version info from built app's Info.plist
   - Generates SHA256 of ZIP, gets file size
   - Creates appcast.xml with Sparkle format
   - Commit: `feat: add appcast generation script`

2. ✅ **Integrate into Makefile**
   - Add APPCAST_PATH and DOWNLOAD_URL variables
   - Call generate-appcast.sh after stapling in notarize target
   - Add standalone `appcast` target
   - Commit: `feat: generate appcast on successful notarization`

## Phase 4: Upload Automation ✅ COMPLETED

**Goal**: Upload both ZIP and appcast.xml to server in one command

### Tasks

1. ✅ **Update upload target**
   - Modify `upload` target to upload both ZIP and appcast.xml
   - Add validation that appcast.xml exists
   - Update success message to show both files
   - Commit: `feat: upload both zip and appcast`

2. ✅ **Update documentation**
   - Update help text in Makefile
   - Commit: `docs: update makefile help text`

## Phase 5: Testing (PENDING USER)

**Goal**: Full end-to-end test of the release pipeline

### Tasks

1. **Test Full Pipeline** (requires user to run `make all`)
   - Run `make all` (release + install + upload)
   - Verify build number incremented
   - Verify ZIP uploaded to server
   - Verify appcast.xml uploaded to server
   - Download appcast.xml and verify URL works

2. **Test Update Check**
   - Build and run app
   - Click "Check for Updates"
   - Verify Sparkle fetches appcast.xml
   - (May show "already up to date" if versions match)

## Commit History

1. `feat: add sparkle framework dependency` - Added Sparkle 2.6.0 to Package.swift
2. `feat: add updater manager wrapper` - Created UpdaterManager, CheckForUpdatesView, Info.plist
3. `feat: integrate updater into app lifecycle` - Added menu item and imports
4. `feat: add update settings` - Added auto-update toggle in Settings
5. `feat: add build number increment script` - scripts/increment-build.sh
6. `feat: auto-increment build on release` - Makefile integration
7. `feat: add appcast generation script` - scripts/generate-appcast.sh
8. `feat: generate appcast on successful notarization` - Makefile integration
9. `feat: upload both zip and appcast` - Updated upload target
10. `docs: update makefile help text` - Documentation

## Files Modified/Created

### New Files
- `Skwad/Updater/UpdaterManager.swift` - Sparkle wrapper and menu view
- `Skwad/Info.plist` - SUFeedURL configuration
- `scripts/increment-build.sh` - Build number automation
- `scripts/generate-appcast.sh` - Appcast generation

### Modified Files
- `Package.swift` - Added Sparkle dependency
- `Skwad.xcodeproj/project.pbxproj` - Project configuration
- `Skwad/SkwadApp.swift` - Menu integration
- `Skwad/Views/Settings/SettingsView.swift` - Auto-update toggle
- `Makefile` - Release pipeline automation

## Environment Variables Required

In `.env` file:
```
APPLE_ID=your.email@example.com
TEAM_ID=ABCD123456
APP_PASSWORD=abcd-efgh-ijkl-mnop
SIGNING_CERTIFICATE=Developer ID Application
SFTP_HOST=home114960941.1and1-data.host
SFTP_PATH=/skwad
SFTP_USER=u37266564
SFTP_KEY=~/.ssh/id_rsa
```

## Success Criteria

✅ Sparkle integrated and functional
✅ Build number auto-increments on `make release`
✅ `make upload` uploads ZIP and appcast.xml
⏳ App successfully checks for updates from server (needs testing)
⏳ Update flow works end-to-end (needs testing)
✅ All changes committed with clear history
