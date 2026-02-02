# Workspaces Feature Plan

## Overview

Add workspace support to Skwad, allowing users to organize agents into separate workspaces. Each workspace has its own set of agents, but all agents across all workspaces remain running (terminals kept alive).

## Requirements

### Core Requirements (from user)
- Vertical workspace bar on the left side of the sidebar
- Each workspace has its own set of agents
- All agents across all workspaces kept alive (not just current workspace)
- Cmd+N adds new workspace (prompts for name)
- Workspace displays as avatar circle with initial(s)
- Right-click context menu: Edit name, Close workspace (closes all agents)
- Workspaces and their agent assignments saved/restored on launch

### Design Decisions (confirmed)

1. **Default workspace**: When last workspace is closed, app shows empty content view. When user creates first agent, auto-create "Skwad" default workspace.

2. **Agent assignment**: New agents added to current workspace. No drag-drop between workspaces (future enhancement).

3. **Keyboard shortcuts**:
   - Cmd+N = New workspace
   - Cmd+1/2/3... = Switch to workspace 1/2/3...
   - Cmd+Shift+W = Close current workspace

4. **Activity indicators**: Workspace avatar shows subtle orange dot if ANY agent in workspace is "working" (one is enough)

5. **Empty workspace**: Shows welcome screen with "Add Agent" button (existing behavior)

6. **Layout per workspace**: Each workspace remembers its own layoutMode, activeAgentIds, focusedPaneIndex, and splitRatio

7. **Workspace color**: User-selectable (color picker in edit sheet)

8. **Workspace reordering**: Drag-drop to reorder workspaces in the bar

9. **No workspace limit**: Users can create as many as they want

## Data Model

### Workspace struct (new)
```swift
struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var color: String  // hex color code, user-selectable
    var agentIds: [UUID]  // ordered list of agents in this workspace

    // Layout state (per-workspace)
    var layoutMode: LayoutMode
    var activeAgentIds: [UUID]  // which agents are visible in panes
    var focusedPaneIndex: Int
    var splitRatio: CGFloat
}
```

### Changes to existing models

**AgentManager changes:**
- Add `workspaces: [Workspace]`
- Add `currentWorkspaceId: UUID`
- Computed `currentWorkspace: Workspace`
- Move layout properties into workspace (layoutMode, activeAgentIds, focusedPaneIndex, splitRatio)
- Keep `agents: [Agent]` as master list (all agents across all workspaces)

**AppSettings changes:**
- Add `savedWorkspacesData: Data` (JSON array of Workspace)
- `saveWorkspaces()` / `loadWorkspaces()` methods
- savedAgents remains unchanged (flat list, workspace association via Workspace.agentIds)

## UI Design

### Layout
```
┌──────────────────────────────────────────────────────────┐
│ Workspace │          Sidebar          │    Terminal      │
│    Bar    │                           │    Content       │
│           │                           │                  │
│   [W1]    │  ┌─────────────────────┐  │                  │
│           │  │ Agent 1             │  │                  │
│   [W2]    │  │ Agent 2             │  │                  │
│           │  │ Agent 3             │  │                  │
│   [W3]    │  │                     │  │                  │
│           │  │                     │  │                  │
│           │  │                     │  │                  │
│   [+]     │  └─────────────────────┘  │                  │
│           │                           │                  │
└──────────────────────────────────────────────────────────┘
```

### Workspace Bar Components
- Width: ~50px fixed
- Background: slightly darker than sidebar
- Each workspace: 40x40 circle with initial(s), tooltip with full name
- Active workspace: highlighted ring/background
- Activity indicator: small orange dot (like Discord)
- "+" button at bottom to add workspace

### Workspace Avatar
- Circle with user-selected color (color picker in edit sheet)
- Shows first 1-2 characters of name (uppercase)
- Default color palette: predefined set of nice colors to choose from

## Implementation Phases

### Phase 1: Data Model & Persistence ✅
**Files:** Agent.swift (minor), AgentManager.swift, AppSettings.swift

1. ✅ Create Workspace struct in new file `Workspace.swift`
2. ✅ Add workspace storage to AppSettings (savedWorkspacesData, save/load methods)
3. ✅ Update AgentManager:
   - Add workspaces array and currentWorkspaceId
   - Migrate layout properties to be workspace-scoped
   - Add workspace CRUD methods (add, remove, rename, switch)
   - Update agent methods to work with current workspace
4. ✅ Migration: On first launch with no workspaces, create "Skwad" workspace containing all existing agents

**Commit:** "feat: add workspace data model and persistence"

### Phase 2: Workspace Bar UI ✅
**Files:** ContentView.swift, new WorkspaceBarView.swift

1. ✅ Create WorkspaceBarView component:
   - Vertical list of workspace avatars
   - Drag-drop reordering
   - "+" button at bottom
   - Click to switch workspace
   - Activity indicator per workspace (subtle orange dot if ANY agent working)
2. ✅ Create WorkspaceAvatarView component:
   - Circle with user-selected color
   - Shows first 1-2 characters of name (uppercase)
   - Selection highlight
3. ✅ Integrate into ContentView layout (left of sidebar)

**Commit:** "feat: add workspace bar UI"

### Phase 3: Workspace Management ✅
**Files:** WorkspaceBarView.swift, new WorkspaceSheet.swift, AgentManager.swift

1. ✅ Create WorkspaceSheet (name + color picker dialog)
2. ✅ Add context menu to workspace avatars:
   - Edit (name + color)
   - Close Workspace (with confirmation if agents exist)
3. ✅ Wire up Cmd+N to create new workspace
4. ✅ Handle empty state (no workspaces): show empty content view, auto-create "Skwad" workspace when first agent created

**Commit:** "feat: add workspace creation and management"

### Phase 4: Per-Workspace Layout ✅
**Files:** AgentManager.swift, ContentView.swift

1. ✅ Move layout state into Workspace struct
2. ✅ Update layout methods to read/write from current workspace
3. ✅ Preserve layout when switching workspaces
4. ✅ Save layout state on changes

**Commit:** "feat: save layout state per workspace"

### Phase 5: Keyboard Shortcuts ✅
**Files:** SkwadApp.swift, AgentManager.swift

1. ✅ Add Cmd+N for new workspace
2. ✅ Add Cmd+1/2/3... shortcuts for workspace switching
3. ✅ Add Ctrl+1/2/3... for agent selection within workspace
4. ✅ Add Cmd+Shift+W for close current workspace
5. ✅ Update menu bar with workspace commands

**Commit:** "feat: add workspace keyboard shortcuts"

### Phase 6: Polish & Edge Cases ✅
**Files:** Various

1. ✅ Activity indicator aggregation (any agent working = workspace working)
2. ✅ Handle last workspace deletion (shows empty state, auto-create on first agent)
3. ✅ Handle agent deletion (update workspace.agentIds)
4. ✅ Smooth animations for workspace switching
5. Accessibility labels (TBD)

**Commit:** "fix: workspace edge cases and polish"

## Testing Checklist

- [ ] Create new workspace with Cmd+N
- [ ] Switch workspaces by clicking
- [ ] Switch workspaces with Cmd+1/2/3
- [ ] Rename workspace via context menu
- [ ] Close workspace via context menu (with agents)
- [ ] Close workspace via context menu (empty)
- [ ] Add agent to workspace
- [ ] Remove agent from workspace
- [ ] Verify layout preserved per workspace
- [ ] Verify all agents stay alive across workspace switches
- [ ] Restart app, verify workspaces restored
- [ ] Delete all agents from workspace, verify empty state
- [ ] Activity indicator shows when agent is working

## Resolved Questions

1. **Workspace color**: User-selectable via color picker
2. **Maximum workspaces**: No limit
3. **Closing last workspace**: Allowed - shows empty content view, auto-creates "Skwad" when first agent added
4. **Workspace order**: Drag-drop to reorder

## Key Learnings

(To be filled after implementation)
