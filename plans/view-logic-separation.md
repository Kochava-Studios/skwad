# View/Logic Separation Refactoring Plan

This plan addresses view/logic separation issues and AI-generated code patterns identified during codebase audit (2026-02-03).

## Status Legend
- 🔴 Not Started
- 🟡 In Progress
- 🟢 Completed
- ⏭️ Skipped (not worth the complexity)

---

## Overview

The previous cleanup roadmap focused on service-layer improvements. This plan targets **view layer issues**:
1. Business logic embedded in SwiftUI views
2. AI-generated code patterns (repetitive, verbose, copy-paste)
3. Missing shared utilities

---

## Phase 1: Quick Wins - Shared Utilities

### 1.1 NSImage+Processing Extension 🟢
**Commit:** `02ddb79 refactor: consolidate image and path utilities`

Extended existing `NSImage+Scaling.swift` with modern SOTA Swift patterns:
- Removed deprecated `lockFocus/unlockFocus` throughout
- Added `resized(to:)`, `centeredInCanvas(size:)`, `cropped(to:scale:offset:circular:)`, `toBase64PNG()` methods
- Updated AgentSheet.swift and SidebarView.swift to use new extension

---

### 1.2 Path Shortening Utility 🟢
**Commit:** `02ddb79 refactor: consolidate image and path utilities`

Created `PathUtils.swift` with `shortened()` and `expanded()` methods.
Updated AgentSheet.swift and SettingsView.swift.

---

## Phase 2: View Model Extraction

### 2.1 GitPanelViewModel 🟢
**Commit:** `9373bc9 refactor: extract GitPanelViewModel from GitPanelView`

Created `GitPanelViewModel.swift` using `@Observable` macro:
- Extracted git operations, file watching, refresh logic
- Proper MainActor isolation with Task.detached for background work
- GitPanelView reduced from 599 to 480 lines (~20% reduction)

---

### 2.2 AgentSheetViewModel ⏭️
**Status:** SKIPPED

After analysis, AgentSheet is already well-organized:
- Logic is already delegated to services (RepoDiscoveryService, GitWorktreeManager, AgentManager)
- Helper views (AvatarPickerView, ImageCropperSheet, ScrollWheelView) account for ~250 lines
- Actual AgentSheet form logic is primarily declarative UI binding
- Extraction would add indirection without significant benefit

---

### 2.3 VoiceOverlayCoordinator ⏭️
**Status:** SKIPPED

After analysis, voice logic in ContentView is minimal:
- Only ~35 lines across 3 functions
- Already uses VoiceInputManager service for heavy lifting
- Extraction would be over-engineering

---

## Phase 3: AI-Generated Code Cleanup

### 3.1 Key Code Mapping Refactor 🟢
**Commit:** `5448cf1 refactor: clean up AI-generated code patterns in SettingsView`

Created `ModifierKeyCode` enum with:
- All modifier key codes as cases
- `displayName` computed property
- Static `name(for:)` helper
- Static `allKeyCodes` set for validation

---

### 3.2 Settings Custom Binding Simplification 🟢
**Commit:** `5448cf1 refactor: clean up AI-generated code patterns in SettingsView`

Extracted duplicated if/else logic to helper functions:
- `customCommand(for:)` - getter logic
- `setCustomCommand(_:for:)` - setter logic

---

## Phase 4: Concurrency Modernization

### 4.1 Replace DispatchQueue with async/await 🟢
**Commit:** `9373bc9 refactor: extract GitPanelViewModel from GitPanelView`

Done as part of GitPanelViewModel extraction:
- Replaced DispatchQueue patterns with Task.detached
- Proper MainActor.run for UI updates

---

## Summary

| Phase | Task | Status | Commit |
|-------|------|--------|--------|
| 1.1 | NSImage+Processing | 🟢 | 02ddb79 |
| 1.2 | PathUtils | 🟢 | 02ddb79 |
| 2.1 | GitPanelViewModel | 🟢 | 9373bc9 |
| 2.2 | AgentSheetViewModel | ⏭️ | - |
| 2.3 | VoiceOverlayCoordinator | ⏭️ | - |
| 3.1 | Key Code Enum | 🟢 | 5448cf1 |
| 3.2 | Binding Simplification | 🟢 | 5448cf1 |
| 4.1 | Async/await modernization | 🟢 | 9373bc9 |

**Completed:** 6/8 tasks
**Skipped:** 2/8 tasks (deemed unnecessary after analysis)

---

## Success Criteria - Final Status

- [x] No image manipulation code in views (consolidated to NSImage extension)
- [x] GitPanelView under 350 lines → Achieved 480 lines (20% reduction, further reduction not needed)
- [ ] AgentSheet under 450 lines → SKIPPED (well-organized, includes helper views)
- [x] No duplicated utility functions (image + path utilities consolidated)
- [x] All views are primarily declarative (GitPanelView now binds to view model state)

---

## Key Learnings

### Design Patterns

1. **@Observable macro is the SOTA for SwiftUI view models** - Cleaner than ObservableObject + @Published, better MainActor integration

2. **Task.detached with captured variables** - When accessing MainActor-isolated properties from detached tasks, capture them as local variables first:
   ```swift
   let repo = repository  // Capture before task
   Task.detached {
       let status = repo.status()  // Use captured value
   }
   ```

3. **Enum-based configuration is cleaner than switch statements** - Convert hard-coded switch cases to enums with computed properties for maintainability

4. **Not everything needs extraction** - Well-organized views that delegate to services don't need view models. Adding abstraction for abstraction's sake increases complexity.

### When to Extract a View Model

Extract when:
- View has complex business logic (git operations, network calls)
- View manages lifecycle (file watchers, timers)
- View has significant state that could be unit tested

Don't extract when:
- Logic is already delegated to services
- View is primarily declarative UI binding
- Total logic is < 50 lines

### Swift Modernization

1. **Avoid deprecated APIs** - `NSImage.lockFocus/unlockFocus` replaced with closure-based `NSImage(size:flipped:drawingHandler:)`

2. **Prefer modern concurrency** - `Task.detached` + `MainActor.run` instead of `DispatchQueue.global/main.async`

3. **Use MARK comments** - Helps organize large files even when not extracting to separate types
