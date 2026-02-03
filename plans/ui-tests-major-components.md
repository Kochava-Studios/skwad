# Major UI Components Test Plan

## Goal
Broad UI coverage for the 4 biggest components + 2 sheets, using ViewInspector + XCTest.
**Strategy**: Wide coverage with happy-path tests (not deep edge cases).

## Target Components

| Component | Priority | Est. Tests |
|-----------|----------|------------|
| ContentView | High | ~15 |
| SettingsView | High | ~18 |
| GitPanelView | High | ~15 |
| SidebarView | High | ~12 |
| NewWorktreeSheet | Medium | ~8 |
| VoiceInputOverlay | Medium | ~6 |
| **Total** | | **~74 tests** |

## Files to Create

```
SkwadTests/Views/
├── ContentViewUITests.swift       (new)
├── Settings/
│   └── SettingsViewUITests.swift  (new)
├── Git/
│   └── GitPanelViewUITests.swift  (new)
├── Sidebar/
│   ├── SidebarViewUITests.swift   (new)
│   └── NewWorktreeSheetUITests.swift (new)
└── Voice/
    └── VoiceInputOverlayUITests.swift (new)
```

---

## Phase 1: ContentView (~15 tests)

**File:** `SkwadTests/Views/ContentViewUITests.swift`

```
ContentViewUITests (XCTestCase, @MainActor)
├── Empty State
│   ├── testEmptyStateShowsWelcomeTitle
│   ├── testEmptyStateShowsCreateButton
│   ├── testEmptyStateShowsMCPCommandView
│   └── testNoWorkspaceShowsFirstWorkspaceSubtitle
├── Workspace Bar
│   ├── testWorkspaceBarRendersWhenWorkspacesExist
│   └── testWorkspaceBarHiddenWhenNoWorkspaces
├── Sidebar
│   ├── testSidebarRendersWhenAgentsExist
│   └── testSidebarHiddenWhenNoAgents
├── Layout Toggle
│   ├── testLayoutMenuAppearsWithTwoAgents
│   ├── testLayoutMenuShowsFourPaneWithThreeAgents
│   └── testLayoutMenuHiddenWithOneAgent
├── Git Button
│   └── testGitButtonPresent
└── Voice Overlay
    ├── testVoiceOverlayHiddenByDefault
    └── testVoiceOverlayShowsMicIcon
```

**Setup helper:**
```swift
private func createAgentManager(agentCount: Int = 0, workspaceCount: Int = 1) -> AgentManager
```

---

## Phase 2: SettingsView (~18 tests)

**File:** `SkwadTests/Views/Settings/SettingsViewUITests.swift`

```
SettingsViewUITests (XCTestCase, @MainActor)
├── Tab Structure
│   ├── testRendersTabView
│   ├── testHasFiveTabs
│   └── testDefaultTabIsGeneral
├── General Tab
│   ├── testGeneralTabShowsAppearancePicker
│   ├── testGeneralTabShowsRestoreAgentsToggle
│   └── testGeneralTabShowsAutoUpdateToggle
├── Coding Tab
│   ├── testCodingTabShowsSourceFolderSection
│   ├── testCodingTabShowsAgentTypePicker
│   └── testCodingTabShowsOptionsField
├── Terminal Tab
│   ├── testTerminalTabShowsEnginePicker
│   └── testTerminalTabShowsFontPicker
├── Voice Tab
│   ├── testVoiceTabShowsEnableToggle
│   ├── testVoiceTabShowsEnginePicker
│   └── testVoiceTabShowsPushToTalkButton
├── MCP Tab
│   ├── testMCPTabShowsEnableToggle
│   ├── testMCPTabShowsPortField
│   └── testMCPTabShowsMCPCommandView
```

---

## Phase 3: GitPanelView (~15 tests)

**File:** `SkwadTests/Views/Git/GitPanelViewUITests.swift`

```
GitPanelViewUITests (XCTestCase, @MainActor)
├── Header
│   ├── testShowsGitStatusTitle
│   ├── testShowsRefreshButton
│   └── testShowsCloseButton
├── Loading State
│   └── testLoadingShowsProgressView
├── Clean State
│   ├── testCleanStateShowsCheckmark
│   └── testCleanStateShowsCleanMessage
├── File List
│   ├── testShowsStagedChangesSection
│   ├── testShowsChangesSection
│   ├── testShowsUntrackedSection
│   └── testShowsConflictsSection
├── Branch Info
│   ├── testShowsBranchName
│   └── testShowsAheadBehindIndicators
├── Diff Section
│   ├── testShowsSelectFileMessage
│   └── testShowsDiffViewWhenSelected
├── Actions
│   └── testCommitButtonAppearsWhenStaged
```

**Note:** Will need mock GitStatus data for testing different states.

---

## Phase 4: SidebarView (~12 tests)

**File:** `SkwadTests/Views/Sidebar/SidebarViewUITests.swift`

```
SidebarViewUITests (XCTestCase, @MainActor)
├── Structure
│   ├── testRendersCollapseButton
│   ├── testRendersWorkspaceTitle
│   └── testRendersNewAgentButton
├── Agent List
│   ├── testRendersAgentRows
│   ├── testAgentRowShowsAvatar
│   ├── testAgentRowShowsName
│   └── testAgentRowShowsStatusCircle
├── Empty State
│   └── testEmptyAgentListShowsNoRows
├── Context Menu
│   ├── testContextMenuHasEditOption
│   ├── testContextMenuHasForkOption
│   └── testContextMenuHasCloseOption
```

---

## Phase 5: NewWorktreeSheet (~8 tests)

**File:** `SkwadTests/Views/Sidebar/NewWorktreeSheetUITests.swift`

```
NewWorktreeSheetUITests (XCTestCase, @MainActor)
├── Structure
│   ├── testShowsNewWorktreeTitle
│   ├── testShowsBranchModePicker
│   └── testShowsDestinationPathField
├── New Branch Mode
│   ├── testNewBranchShowsNameField
│   └── testNewBranchHidesBranchMenu
├── Existing Branch Mode
│   ├── testExistingBranchShowsBranchMenu
│   └── testExistingBranchHidesNameField
├── Buttons
│   └── testShowsCreateAndCancelButtons
```

---

## Phase 6: VoiceInputOverlay (~6 tests)

**File:** `SkwadTests/Views/Voice/VoiceInputOverlayUITests.swift`

```
VoiceInputOverlayUITests (XCTestCase, @MainActor)
├── Structure
│   ├── testShowsMicIcon
│   ├── testShowsStatusText
│   └── testShowsHelpText
├── Transcription
│   └── testShowsTranscriptionWhenAvailable
├── Buttons
│   ├── testShowsCancelButton
│   └── testShowsInsertButton
```

---

## Commit Strategy

1. `test: add ContentView UI tests`
2. `test: add SettingsView UI tests`
3. `test: add GitPanelView UI tests`
4. `test: add SidebarView UI tests`
5. `test: add NewWorktreeSheet UI tests`
6. `test: add VoiceInputOverlay UI tests`

---

## Technical Notes

### Pattern (from AgentSheetUITests)
```swift
import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

@MainActor
final class ComponentUITests: XCTestCase {

    private func createAgentManager() -> AgentManager {
        let manager = AgentManager()
        if manager.workspaces.isEmpty {
            manager.workspaces = [Workspace.createDefault()]
            manager.currentWorkspaceId = manager.workspaces.first?.id
        }
        return manager
    }

    func testSomethingExists() throws {
        let view = SomeView()
            .environmentObject(createAgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { (try? $0.string() == "Expected") ?? false }
        XCTAssertTrue(hasLabel, "Should show 'Expected' label")
    }
}
```

### Key Rules
- Use **XCTest** (not Swift Testing @Test macros) - ViewInspector crashes with Swift Testing
- Add **@MainActor** to test classes using AgentManager
- Use `.environmentObject(createAgentManager())` for views needing it
- Use `view.inspect().findAll(ViewType.X.self)` to find elements
- Test element **presence**, not deep behavior

---

## Verification

After each phase:
```bash
xcodebuild -scheme SkwadTests -destination 'platform=macOS' test
```

Expected: ~565 tests total (491 existing + 74 new)
