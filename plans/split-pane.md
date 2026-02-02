# Split Pane Feature

## Requirements

- Layout toggle button in the header (right side), visible when ≥2 agents exist
- Cycles: single → vertical split (HSplitView) → horizontal split (VSplitView) → single
- Entering split: 2nd pane gets the next agent after current
- Panes have a subtle focus ring; clicking a pane gives it keyboard focus
- Clicking an agent in sidebar assigns it to the **focused** pane
- If that agent is already in the other pane → swap the two
- Can't have same agent in both panes

## Edge Cases

| Case | Behavior |
|------|----------|
| Close agent in a pane | Collapse to single pane, surviving agent becomes selected |
| Close agent NOT in any pane | No layout change |
| Restart agent in a pane | Stays in pane (restart doesn't remove) |
| Add agent while in split | Stays in split, new agent not auto-assigned |
| Ctrl+Tab in split | Cycles agents into focused pane, skipping the other pane's agent |
| Cmd+1-9 in split | If agent is in a pane → focus that pane. Otherwise → assign to focused pane |
| Git panel | Opens for focused pane's agent |
| Voice input | Injects into focused pane's terminal (already works if focus is correct) |
| Agents drop below 2 | Force single pane, button disappears |

---

## Architecture

### The constraint

Ghostty terminals are created in `GhosttyHostView.makeNSView()` and tied to NSView lifecycle. No `AgentTerminalView` can ever leave the view tree or move between SwiftUI containers — that destroys the NSView. The existing ZStack + ForEach + opacity trick is the mechanism that keeps them alive. We must not change that structure.

### The solution: same ZStack, add frame + offset

**Zero structural change to the view tree.** Every agent stays in the exact same `ForEach` inside the exact same `ZStack`. The only thing that changes per-agent is `.frame()` and `.offset()` — layout modifiers that reposition the underlying NSView via `updateNSView`, never destroy it. Ghostty already handles arbitrary resize in `updateNSView` (it already receives `size` from a GeometryReader and calls `needsLayout`).

The split divider and focus ring are pure **overlay** views rendered on top of the ZStack. They have no effect on the ForEach or agent lifecycle.

---

## Technical Design

### 1. AgentManager — new state + methods

#### New enum (top of file, before class)

```swift
enum LayoutMode {
    case single
    case splitVertical   // left | right
    case splitHorizontal // top / bottom
}
```

#### New published properties

```swift
@Published var layoutMode: LayoutMode = .single
@Published var secondaryAgentId: UUID? = nil
@Published var focusedPaneIndex: Int = 0   // 0 = primary, 1 = secondary
@Published var splitRatio: CGFloat = 0.5
```

#### New computed property

```swift
/// The agent that currently has keyboard focus (used for git panel, voice, keyboard shortcuts)
var activeAgentId: UUID? {
    layoutMode == .single ? selectedAgentId
        : (focusedPaneIndex == 0 ? selectedAgentId : secondaryAgentId)
}
```

#### New methods

```swift
func toggleLayout() {
    guard agents.count >= 2 else { return }
    switch layoutMode {
    case .single:
        enterSplit(.splitVertical)
    case .splitVertical:
        layoutMode = .splitHorizontal
    case .splitHorizontal:
        exitSplit()
    }
}

func enterSplit(_ mode: LayoutMode) {
    guard agents.count >= 2 else { return }
    // Pick next agent after selected as secondary
    guard let currentIndex = agents.firstIndex(where: { $0.id == selectedAgentId }) else { return }
    let nextIndex = (currentIndex + 1) % agents.count
    secondaryAgentId = agents[nextIndex].id
    layoutMode = mode
    focusedPaneIndex = 0
}

func exitSplit() {
    // The focused pane's agent becomes the single selected agent
    if focusedPaneIndex == 1, let secId = secondaryAgentId {
        selectedAgentId = secId
    }
    secondaryAgentId = nil
    layoutMode = .single
    focusedPaneIndex = 0
}

func focusPane(_ index: Int) {
    guard layoutMode != .single else { return }
    focusedPaneIndex = index
}

func assignAgentToFocusedPane(_ agentId: UUID) {
    guard layoutMode != .single else {
        // Single mode: just select it (existing behavior)
        selectedAgentId = agentId
        return
    }

    if focusedPaneIndex == 0 {
        if secondaryAgentId == agentId {
            // Agent is in the other pane → swap
            let tmp = selectedAgentId
            selectedAgentId = agentId
            secondaryAgentId = tmp
        } else {
            selectedAgentId = agentId
        }
    } else {
        if selectedAgentId == agentId {
            // Agent is in the other pane → swap
            let tmp = secondaryAgentId
            secondaryAgentId = agentId
            selectedAgentId = tmp
        } else {
            secondaryAgentId = agentId
        }
    }
}
```

#### Updated methods

**`removeAgent`** — after the existing removal logic, add:
```swift
// If we were in split and the removed agent was in a pane, collapse
if layoutMode != .single {
    if secondaryAgentId == nil || selectedAgentId == nil || agents.count < 2 {
        layoutMode = .single
        secondaryAgentId = nil
        focusedPaneIndex = 0
        // selectedAgentId already set to agents.first by existing logic
    }
}
```

**`selectNextAgent` / `selectPreviousAgent`** — in split mode, cycle agents into the focused pane, skipping the other pane's agent:
```swift
func selectNextAgent() {
    guard !agents.isEmpty else { return }
    if layoutMode != .single {
        // Cycle into focused pane, skip other pane's agent
        let otherPaneId = focusedPaneIndex == 0 ? secondaryAgentId : selectedAgentId
        let currentId = focusedPaneIndex == 0 ? selectedAgentId : secondaryAgentId
        guard let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else { return }
        var next = (currentIndex + 1) % agents.count
        while agents[next].id == otherPaneId {
            next = (next + 1) % agents.count
        }
        if focusedPaneIndex == 0 {
            selectedAgentId = agents[next].id
        } else {
            secondaryAgentId = agents[next].id
        }
        return
    }
    // ... existing single-mode logic unchanged
}
// selectPreviousAgent: same pattern, decrement instead
```

**`selectAgentAtIndex`** — in split mode:
```swift
func selectAgentAtIndex(_ index: Int) {
    guard index >= 0 && index < agents.count else { return }
    let agentId = agents[index].id
    if layoutMode != .single {
        // If agent is already in a pane, focus that pane
        if agentId == selectedAgentId {
            focusedPaneIndex = 0
        } else if agentId == secondaryAgentId {
            focusedPaneIndex = 1
        } else {
            // Assign to focused pane
            assignAgentToFocusedPane(agentId)
        }
        return
    }
    selectedAgentId = agentId
}
```

**`addAgent`** — in split mode, assign to focused pane instead of just setting selectedAgentId:
```swift
// Replace: selectedAgentId = agent.id
// With:
if layoutMode != .single {
    assignAgentToFocusedPane(agent.id)
} else {
    selectedAgentId = agent.id
}
```

---

### 2. ContentView — layout + overlays

#### Wrap the ZStack in a GeometryReader

The current structure (ContentView.swift lines 56–153):
```swift
ZStack {
  ForEach(agentManager.agents) { agent in
    AgentTerminalView(...)
      .id(...)
      .opacity(agentManager.selectedAgentId == agent.id ? 1 : 0)
      .allowsHitTesting(agentManager.selectedAgentId == agent.id)
  }
  // empty state ...
  // git toggle button ...
}
```

Becomes:
```swift
GeometryReader { geo in
  ZStack(alignment: .topLeading) {
    ForEach(agentManager.agents) { agent in
      let rect = paneRect(for: agent, in: geo.size)
      let visible = isAgentVisible(agent)

      AgentTerminalView(agent: agent, sidebarVisible: $sidebarVisible,
                        onGitStatsTap: { ... },
                        onPaneTap: { agentManager.focusPane(paneIndex(for: agent)) })
        .id("\(agent.id)-\(agent.restartToken)")
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
    }

    // Empty state (unchanged, only shown when agents.isEmpty)
    if agentManager.agents.isEmpty { ... }

    // Git toggle button — position in bottom-right of active pane
    if canShowGitPanel { ... }

    // Split mode overlays
    if agentManager.layoutMode != .single {
      splitDivider(in: geo.size)
      focusRingOverlay(in: geo.size)
    }
  }
}
```

#### Helper functions (private, in ContentView)

```swift
/// Which pane an agent belongs to (for sizing/positioning)
private func paneIndex(for agent: Agent) -> Int {
    agent.id == agentManager.secondaryAgentId ? 1 : 0
}

/// Whether an agent should be visible
private func isAgentVisible(_ agent: Agent) -> Bool {
    if agentManager.layoutMode == .single {
        return agent.id == agentManager.selectedAgentId
    }
    return agent.id == agentManager.selectedAgentId || agent.id == agentManager.secondaryAgentId
}

/// Compute the rect for an agent based on its pane assignment and layout mode
private func paneRect(for agent: Agent, in size: CGSize) -> CGRect {
    if agentManager.layoutMode == .single {
        return CGRect(origin: .zero, size: size)
    }
    let pane = paneIndex(for: agent)
    return computePaneRect(pane, in: size)
}

/// Compute rect for a pane index given layout mode and split ratio
private func computePaneRect(_ pane: Int, in size: CGSize) -> CGRect {
    let ratio = agentManager.splitRatio
    switch agentManager.layoutMode {
    case .single:
        return CGRect(origin: .zero, size: size)
    case .splitVertical:  // left | right
        let w0 = size.width * ratio
        let w1 = size.width - w0
        return pane == 0
            ? CGRect(x: 0, y: 0, width: w0, height: size.height)
            : CGRect(x: w0, y: 0, width: w1, height: size.height)
    case .splitHorizontal:  // top / bottom
        let h0 = size.height * ratio
        let h1 = size.height - h0
        return pane == 0
            ? CGRect(x: 0, y: 0, width: size.width, height: h0)
            : CGRect(x: 0, y: h0, width: size.width, height: h1)
    }
}
```

#### Split divider overlay

```swift
private func splitDivider(in size: CGSize) -> some View {
    let isVertical = agentManager.layoutMode == .splitVertical
    let pos = isVertical ? size.width * agentManager.splitRatio : size.height * agentManager.splitRatio

    return Rectangle()
        .fill(Color.primary.opacity(0.15))
        .frame(
            width: isVertical ? 6 : size.width,
            height: isVertical ? size.height : 6
        )
        .offset(
            x: isVertical ? pos - 3 : 0,
            y: isVertical ? 0 : pos - 3
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                (isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newRatio: CGFloat
                    if isVertical {
                        newRatio = (pos + value.translation.width) / size.width
                    } else {
                        newRatio = (pos + value.translation.height) / size.height
                    }
                    agentManager.splitRatio = max(0.25, min(0.75, newRatio))
                }
        )
}
```

#### Focus ring overlay

```swift
private func focusRingOverlay(in size: CGSize) -> some View {
    let focusedRect = computePaneRect(agentManager.focusedPaneIndex, in: size)

    return RoundedRectangle(cornerRadius: 4)
        .stroke(Color.accentColor.opacity(0.5), lineWidth: 1.5)
        .frame(width: focusedRect.width, height: focusedRect.height)
        .offset(x: focusedRect.minX, y: focusedRect.minY)
        .allowsHitTesting(false)  // doesn't intercept clicks
}
```

#### Click-to-focus

Clicking the header of a pane sets focus. `AgentTerminalView` gets an `onPaneTap` callback. The header's existing `.gesture(WindowDragGesture())` area gets an `.onTapGesture` that calls `onPaneTap`. This is the simplest approach — headers are already rendered, already have tap handling for git stats, and are the natural "grab bar" for a pane.

#### Git panel and git toggle button in split mode

- `canShowGitPanel` uses `selectedAgent` today → change to use `activeAgent` (agent in focused pane)
- Git panel (`GitPanelView`) uses `agent.folder` → same, use active agent's folder
- Git toggle button position: currently bottom-right of the ZStack. In split mode it should be bottom-right of the **active pane's rect**. Use `.offset()` to position it within that rect.
- `onChange(of: selectedAgentId)` that closes git panel → also trigger on `focusedPaneIndex` change and `secondaryAgentId` change

---

### 3. AgentTerminalView — isActive + layout toggle button + onPaneTap

#### isActive

Currently:
```swift
private var isActive: Bool {
    agentManager.selectedAgentId == agent.id
}
```

Change to:
```swift
private var isActive: Bool {
    agentManager.activeAgentId == agent.id
}
```

#### onPaneTap callback

Add a parameter:
```swift
let onPaneTap: () -> Void
```

Pass it down to the header. In `AgentFullHeader`, add it as a param and wire it to the header's tap area (the left HStack that currently has `WindowDragGesture`):
```swift
.onTapGesture {
    onPaneTap()
}
```

#### Layout toggle button

Add to `AgentFullHeader`, between the left content and the right git stats. Only shown when:
- `agentManager.agents.count >= 2`
- This agent is the primary agent (`agent.id == agentManager.selectedAgentId`) — so the button only appears in pane 0's header

```swift
if agentManager.agents.count >= 2 && agent.id == agentManager.selectedAgentId {
    Button {
        agentManager.toggleLayout()
    } label: {
        let icon: String
        switch agentManager.layoutMode {
        case .single:          icon = "square.split.vertical"
        case .splitVertical:   icon = "square.split.horizontal"
        case .splitHorizontal: icon = "square"
        }
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(Theme.secondaryText)
    }
    .buttonStyle(.plain)
    .help("Toggle split pane")
}
```

---

### 4. SidebarView — tap handler

Currently (line 99–101):
```swift
AgentRowView(agent: agent, isSelected: agentManager.selectedAgentId == agent.id)
    .onTapGesture {
        agentManager.selectedAgentId = agent.id
    }
```

Change to:
```swift
AgentRowView(agent: agent, isSelected: isAgentActive(agent))
    .onTapGesture {
        agentManager.assignAgentToFocusedPane(agent.id)
    }
```

Where `isAgentActive` highlights the agent if it's in either pane (in split mode) or selected (in single mode):
```swift
private func isAgentActive(_ agent: Agent) -> Bool {
    agent.id == agentManager.selectedAgentId || agent.id == agentManager.secondaryAgentId
}
```

Consider also showing which pane an agent is in — e.g. a subtle "1" or "2" badge. But that's polish, not core.

---

### 5. SkwadApp — keyboard shortcuts

**Ctrl+Tab / Ctrl+Shift+Tab** — already call `selectNextAgent()` / `selectPreviousAgent()`. Those methods are updated in AgentManager to handle split mode. No change needed here.

**Cmd+1-9** — already calls `selectAgentAtIndex()`. That method is updated. No change needed here.

**Cmd+Delete (Close Current Agent)** — currently closes `selectedAgentId`. In split mode should close `activeAgentId`:
```swift
Button("Close Current Agent") {
    if let agent = agentManager.agents.first(where: { $0.id == agentManager.activeAgentId }) {
        agentToClose = agent
        showCloseConfirmation = true
    }
}
```

**Shift+Cmd+C (Clear Agent)** — same, use `activeAgentId`:
```swift
Button("Clear Agent") {
    if let activeId = agentManager.activeAgentId {
        agentManager.injectText("/clear", for: activeId)
    }
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `Skwad/Models/AgentManager.swift` | LayoutMode enum, 4 new @Published, activeAgentId computed, 5 new methods, updates to removeAgent/selectNext/selectPrevious/selectAtIndex/addAgent |
| `Skwad/Views/ContentView.swift` | GeometryReader wrapper, frame+offset per agent, paneRect helpers, splitDivider, focusRingOverlay, git panel uses activeAgent |
| `Skwad/Views/Terminal/AgentTerminalView.swift` | isActive → activeAgentId, onPaneTap callback, layout toggle button in AgentFullHeader |
| `Skwad/Views/Sidebar/SidebarView.swift` | onTapGesture → assignAgentToFocusedPane, isSelected highlights both pane agents |
| `Skwad/SkwadApp.swift` | Cmd+Delete and Shift+Cmd+C use activeAgentId |

## Commit Strategy

1. `feat: add layout mode state to AgentManager` — LayoutMode enum + published state + all new/updated methods
2. `feat: add split pane layout to ContentView` — GeometryReader, frame+offset, paneRect helpers, divider, focus ring
3. `feat: add layout toggle button to header` — Button in AgentFullHeader, isActive → activeAgentId, onPaneTap
4. `feat: wire sidebar selection for split mode` — assignAgentToFocusedPane on tap, highlight both pane agents
5. `feat: update keyboard shortcuts for split mode` — activeAgentId in Cmd+Delete, Shift+Cmd+C
6. `fix: handle split mode edge cases` — removeAgent collapse, agents < 2 guard

## Verification

1. Build (Cmd+R), create 2+ agents
2. Layout toggle button appears in pane 0 header → click through all 3 modes
3. Verify correct agents in each pane on split entry
4. **Switch agents in single mode → verify all terminals retain state**
5. **Enter split → verify both terminals retain state**
6. **Switch secondary agent → verify old secondary retains state when switching back**
7. Click pane headers → focus ring moves, keyboard goes to correct terminal
8. Click sidebar agent → assigns to focused pane; click agent in other pane → swap
9. Close agent in pane → collapses to single
10. Ctrl+Tab cycles correctly (skips other pane's agent)
11. Cmd+1-9 focuses pane or assigns correctly
12. Git panel opens for focused pane's agent, closes on pane switch
13. Drag split divider → both panes resize, terminals adapt
14. Voice input (Shift+Space) injects into focused pane's terminal
