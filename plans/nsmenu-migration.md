# NSMenu Migration: File & View Menus

## Goal

Replace the SwiftUI `CommandGroup` menus for File and View with native `NSMenu` built in AppDelegate. This eliminates:
- Menu items flickering/disappearing on state changes
- Keyboard shortcuts going AWOL during menu rebuilds
- The `removeDefaultCloseMenuItem` polling timer hack
- Cmd+W fighting with SwiftUI's default Close behavior

## Current State

### File menu (SwiftUI `CommandGroup(replacing: .newItem)`)
| Item | Shortcut | Dynamic? |
|------|----------|----------|
| New Workspace... | Cmd+N | No |
| New Agent... | Cmd+T | No |
| Recent Agents > (submenu) | — | Yes (list of recent agents) |
| Broadcast to All Agents... | Cmd+Shift+B | Disabled when no agents |
| Open in \<App\> | Cmd+Shift+O | Conditional (only if setting configured) |
| Close Agent | Cmd+W | Disabled when no active agent |
| Close Workspace | Cmd+Shift+W | Disabled when no workspace |
| Quit Skwad | Cmd+Shift+Q | No |

Plus the Cmd+W key monitor hack in AppDelegate and the 0.5s timer to hide default Close items.

### View menu (SwiftUI `CommandGroup(after: .sidebar)`)
| Item | Shortcut | Dynamic? |
|------|----------|----------|
| Toggle Git Panel | Cmd+/ | No (triggers binding toggle) |
| Toggle Sidebar | Cmd+Option+B | No (triggers binding toggle) |
| Next Agent | Cmd+] | No |
| Previous Agent | Cmd+[ | No |
| \<Workspace 1-9\> | Cmd+1-9 | Yes (workspace list) |
| \<Agent 1-9\> | Ctrl+1-9 | Yes (agent list) |

### Edit menu (SwiftUI `CommandGroup(after: .textEditing)`)
| Item | Shortcut | Dynamic? |
|------|----------|----------|
| Clear Agent | Cmd+K | Disabled when no active agent |
| Restart Current Agent | Cmd+R | Disabled when no active agent |

## Plan

### Phase 1: Create `MenuManager` class

New file: `Skwad/Services/MenuManager.swift`

A `@MainActor` class that:
- Takes a weak reference to `AgentManager`
- Owns all NSMenu building and updating
- Uses `NSMenuDelegate` (`menuNeedsUpdate`) for dynamic content (lazy rebuild only when opened)
- Provides callback closures for UI actions that need SwiftUI state (sheets, toggles)

### Phase 2: Build File menu as NSMenu

Build the full File menu in `MenuManager`:
- All items with their keyboard shortcuts via `NSMenuItem.keyEquivalent`
- Cmd+W → Close Agent (no more key monitor hack!)
- Cmd+Shift+W → Close Workspace
- Recent Agents submenu with `NSMenuDelegate` for lazy population
- "Open in \<App\>" conditional item
- Disable state via `menuNeedsUpdate` (checked right before the menu opens)

Remove from SkwadApp:
- The entire `CommandGroup(replacing: .newItem)` block
- The `removeDefaultCloseMenuItem()` timer hack
- The `setupKeyEventMonitor()` hack

### Phase 3: Build View menu as NSMenu

Build the View items in `MenuManager`:
- Toggle Git Panel (Cmd+/)
- Toggle Sidebar (Cmd+Option+B)
- Next/Previous Agent (Cmd+]/[)
- Workspace list (Cmd+1-9) — populated in `menuNeedsUpdate`
- Agent list (Ctrl+1-9) — populated in `menuNeedsUpdate`

Remove from SkwadApp:
- The entire `CommandGroup(after: .sidebar)` block

### Phase 4: Build Edit menu items as NSMenu

Add to the existing Edit menu:
- Clear Agent (Cmd+K)
- Restart Current Agent (Cmd+R)

Remove from SkwadApp:
- The `CommandGroup(after: .textEditing)` block

### Phase 5: Wire up and clean up

- Initialize `MenuManager` in `AppDelegate.applicationDidFinishLaunching` (after agentManager is set)
- Bridge actions that need SwiftUI state (show sheets) via `NotificationCenter` posts from MenuManager → SkwadApp listeners
- Remove all `CommandGroup` blocks from SkwadApp (only keep the Settings `CommandGroup` for Sparkle updater)
- Remove the Cmd+W key event monitor
- Remove the `removeDefaultCloseMenuItem` timer
- Remove `toggleGitPanel` and `toggleSidebar` bindings from SkwadApp → ContentView chain (ContentView can listen to notifications directly)
- Clean up unused `@State` properties from SkwadApp

### Phase 6: Test and commit

- Build and verify all menu items appear correctly
- Verify all keyboard shortcuts work
- Verify dynamic items (workspace list, agent list, recent agents) update when menus are opened
- Verify disabled states work correctly
- Commit

## Architecture Notes

### Why `menuNeedsUpdate` instead of rebuilding on every state change
`NSMenuDelegate.menuNeedsUpdate(_:)` is called **only when the user opens the menu**. This means:
- Zero overhead during normal operation (no rebuilds on agent status changes)
- Menu items are always correct when the user sees them
- Keyboard shortcuts are permanently registered — they never disappear

### Bridging NSMenu actions to SwiftUI
For actions that mutate `AgentManager` directly (close agent, select agent, etc.), we call the manager directly since it's `@MainActor`.

For actions that need SwiftUI sheets/alerts (new agent, broadcast, etc.), we post notifications that SwiftUI views listen to via `.onReceive`.

### Notifications for sheet triggers
```
.showNewAgentSheet     — already exists
.showNewWorkspaceSheet — new
.showBroadcastSheet    — new
.toggleGitPanel        — new
.toggleSidebar         — new
```

## Commit Strategy

1. `feat: add MenuManager with NSMenu-based File, View, and Edit menus`
2. `refactor: remove SwiftUI CommandGroup menus and menu hacks`

Or if cleaner as one: `refactor: replace SwiftUI menus with native NSMenu`
