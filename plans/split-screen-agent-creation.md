# Design: Split Screen on Agent Creation

## Task Summary

When an agent creates another agent via the `create-agent` MCP tool, add an optional `split_screen` boolean parameter (default `false`). When `true`, the new agent automatically shares the screen with the creator using the existing multi-pane layout system.

## Behavior Specification

| Current Layout State | Action When `split_screen=true` |
|---------------------|--------------------------------|
| Single pane | → Dual vertical split (creator left, new agent right) |
| Dual pane (2 agents) | → Four-pane grid (add new agent to pane 3 or 4) |
| Four-pane (all slots filled) | → Replace a pane (priority: 4 → 3 → 2 → 1, skip creator's pane) |

### Pane Replacement Priority

When in four-pane mode with all slots filled:
1. Try to replace pane #4 (bottom-right) if it's not the creator
2. Then pane #3 (bottom-left) if it's not the creator
3. Then pane #2 (top-right) if it's not the creator
4. Then pane #1 (top-left) if it's not the creator (last resort, creator gets replaced)

## Current Architecture Analysis

### Relevant Files

1. **MCPTools.swift:88-103** - `create-agent` tool definition
2. **MCPTools.swift:297-332** - `handleCreateAgent()` implementation
3. **MCPService.swift:345-411** - `createAgent()` actor method
4. **MCPService.swift:462-522** - `AgentManagerWrapper.addAgent()` bridge
5. **AgentManager.swift:82-107** - Layout state properties
6. **AgentManager.swift:547-584** - `enterSplit()`, `selectAgent()`, `focusPane()`

### Current Flow

```
MCP Tool Call → MCPTools.handleCreateAgent()
             → MCPService.createAgent()
             → AgentManagerWrapper.addAgent()
             → AgentManager.addAgent()
```

The current implementation does NOT touch layout state - the new agent is simply added to the workspace and remains invisible until manually selected.

## Proposed Changes

### 1. MCPTools.swift - Add Tool Parameter

**File:** `Skwad/MCP/MCPTools.swift`

Add `splitScreen` property to the tool definition (around line 99):

```swift
"splitScreen": PropertySchema(type: "boolean", description: "If true, new agent shares screen with creator (split view)")
```

Extract the parameter in `handleCreateAgent()` (around line 310):

```swift
let splitScreen = arguments["splitScreen"] as? Bool ?? false
```

Pass to `mcpService.createAgent()`:

```swift
let result = await mcpService.createAgent(
    name: name,
    icon: icon,
    agentType: agentType,
    repoPath: repoPath,
    createWorktree: createWorktree,
    branchName: branchName,
    createdBy: createdBy,
    splitScreen: splitScreen  // NEW
)
```

### 2. MCPService.swift - Pass Through Parameter

**File:** `Skwad/MCP/MCPService.swift`

Update `createAgent()` signature (line 345):

```swift
func createAgent(
    name: String,
    icon: String?,
    agentType: String,
    repoPath: String,
    createWorktree: Bool,
    branchName: String?,
    createdBy: UUID?,
    splitScreen: Bool  // NEW
) async -> CreateAgentResponse
```

Pass `splitScreen` to provider (line 405):

```swift
if let agentId = await provider.addAgent(
    folder: folder,
    name: name,
    avatar: icon,
    agentType: agentType,
    createdBy: createdBy,
    splitScreen: splitScreen  // NEW
) {
```

### 3. AgentDataProvider Protocol - Extend Signature

**File:** `Skwad/MCP/MCPService.swift` (line 25)

```swift
func addAgent(folder: String, name: String, avatar: String?, agentType: String, createdBy: UUID?, splitScreen: Bool) async -> UUID?
```

### 4. AgentManagerWrapper - Pass Parameter

**File:** `Skwad/MCP/MCPService.swift` (line 511)

Update the wrapper method:

```swift
func addAgent(folder: String, name: String, avatar: String?, agentType: String, createdBy: UUID?, splitScreen: Bool) async -> UUID? {
    await MainActor.run {
        guard let manager = manager else { return nil }
        let countBefore = manager.agents.count
        let newAgentId = manager.addAgent(
            folder: folder,
            name: name,
            avatar: avatar,
            agentType: agentType,
            createdBy: createdBy
        )

        // Handle split screen if requested and agent was created
        if splitScreen, let agentId = newAgentId, let creatorId = createdBy {
            manager.enterSplitWithNewAgent(newAgentId: agentId, creatorId: creatorId)
        }

        return newAgentId
    }
}
```

### 5. AgentManager - Core Logic

**File:** `Skwad/Models/AgentManager.swift`

**5a. Modify `addAgent()` to return the new agent's ID:**

Current signature returns `Void`. Change to return `UUID?`:

```swift
@discardableResult
func addAgent(folder: String, name: String, avatar: String?, agentType: String, createdBy: UUID?) -> UUID? {
    // ... existing implementation ...
    // At the end, return the new agent's ID
    return agent.id
}
```

**5b. Add new method `enterSplitWithNewAgent()`:**

```swift
/// Enters split view showing the creator agent and a newly created agent
/// Called when an agent creates another agent with splitScreen=true
func enterSplitWithNewAgent(newAgentId: UUID, creatorId: UUID) {
    // Find which pane the creator is in (if any)
    let creatorPane = paneIndex(for: creatorId)

    switch layoutMode {
    case .single:
        // Single → Dual vertical: creator left (0), new agent right (1)
        activeAgentIds = [creatorId, newAgentId]
        layoutMode = .splitVertical
        focusedPaneIndex = 1  // Focus the new agent

    case .splitVertical, .splitHorizontal:
        // Dual → Four-pane grid
        // Keep existing 2 agents in panes 0 and 1
        // Add new agent to pane 2 (bottom-left)
        var newActiveIds = activeAgentIds
        newActiveIds.append(newAgentId)
        // If we need a 4th, pick any agent not already shown
        if newActiveIds.count < 4 {
            if let fourthAgent = currentWorkspaceAgents.first(where: {
                !newActiveIds.contains($0.id) && $0.id != newAgentId
            }) {
                newActiveIds.append(fourthAgent.id)
            }
        }
        activeAgentIds = Array(newActiveIds.prefix(4))
        layoutMode = .gridFourPane
        // Focus the new agent's pane
        if let newPane = activeAgentIds.firstIndex(of: newAgentId) {
            focusedPaneIndex = newPane
        }

    case .gridFourPane:
        // Four-pane already full: replace a pane (not the creator's)
        // Priority: 4 (index 3) → 3 (index 2) → 2 (index 1) → 1 (index 0)
        let replacementOrder = [3, 2, 1, 0]
        var replacedPane: Int? = nil

        for pane in replacementOrder {
            if pane != creatorPane {
                activeAgentIds[pane] = newAgentId
                replacedPane = pane
                break
            }
        }

        // Edge case: creator is in all considered panes (shouldn't happen, but fallback)
        if replacedPane == nil {
            // Replace pane 3 regardless
            activeAgentIds[3] = newAgentId
            replacedPane = 3
        }

        focusedPaneIndex = replacedPane ?? 3
    }
}
```

## Implementation Order

1. **MCPTools.swift** - Add `splitScreen` parameter to tool definition
2. **MCPTools.swift** - Extract parameter in `handleCreateAgent()`
3. **MCPService.swift** - Update `createAgent()` signature and pass through
4. **MCPService.swift** - Update `AgentDataProvider` protocol
5. **MCPService.swift** - Update `AgentManagerWrapper.addAgent()`
6. **AgentManager.swift** - Modify `addAgent()` to return `UUID?`
7. **AgentManager.swift** - Add `enterSplitWithNewAgent()` method

## Commit Strategy

1. **Commit 1:** "feat: add splitScreen parameter to create-agent MCP tool"
   - MCPTools.swift changes (tool definition + handler)
   - MCPService.swift signature changes (pass-through only, no logic yet)

2. **Commit 2:** "feat: implement split screen layout on agent creation"
   - AgentManager.swift changes (return UUID, new enterSplitWithNewAgent method)
   - AgentManagerWrapper integration

## Testing Checklist

- [ ] Create agent without `splitScreen` → agent added but layout unchanged
- [ ] Create agent with `splitScreen=true` from single pane → dual vertical
- [ ] Create agent with `splitScreen=true` from dual pane → four-pane grid
- [ ] Create agent with `splitScreen=true` from full four-pane → pane replacement
- [ ] Verify creator's pane is preserved during replacement
- [ ] Verify new agent gets focus after split
- [ ] Verify layout persists after app restart

## Implementation Status

- [x] MCPTools.swift - Add `splitScreen` parameter to tool definition
- [x] MCPTools.swift - Extract parameter in `handleCreateAgent()`
- [x] MCPService.swift - Update `createAgent()` signature and pass through
- [x] MCPService.swift - Update `AgentDataProvider` protocol
- [x] MCPService.swift - Update `AgentManagerWrapper.addAgent()`
- [x] AgentManager.swift - Modify `addAgent()` to return `UUID?`
- [x] AgentManager.swift - Add `enterSplitWithNewAgent()` method
- [x] Build passes
