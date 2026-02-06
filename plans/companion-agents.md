# Companion Agents Feature

## Overview

Replace the current `splitScreen` parameter in `create-agent` MCP tool with a `companion` concept. A companion agent is attached to its owner with these behaviors:

- Does **not** appear in the sidebar agent list
- Its display (visible in a pane) is linked to the owner's display
- An owner can have **up to 3 companions** (enforced)
- When owner is closed → all companions are closed
- Companion can be closed independently without affecting the owner
- The `companion` flag is optional; agents are told to only use it if explicitly asked by the user

No backwards compatibility needed — `splitScreen` is simply replaced.

## Ownership Model

Two fields work together:
- **`createdBy: UUID?`** — already exists, tracks which agent created this one (used for close-agent permissions). This is the ownership link.
- **`isCompanion: Bool`** — new field, qualifies the `createdBy` relationship. When `true`, this agent is a companion of the `createdBy` agent.

So: `createdBy` = parent link, `isCompanion` = "what kind of child". A non-companion created agent (e.g. a regular `create-agent` call) has `createdBy` set but `isCompanion = false`. A companion has both set.

Two different owners can each have their own set of companions — the pairing is `createdBy` + `isCompanion`.

Finding companions of agent X: `agents.filter { $0.createdBy == X.id && $0.isCompanion }`

## Design

### 1. Agent Model (`Agent.swift`)

Add a new persisted property:

```swift
var isCompanion: Bool = false
```

Add to `CodingKeys` and `init` parameters (default `false`).

### 2. MCP Tool Definition (`MCPTools.swift`)

In `create-agent` tool definition:
- Remove `splitScreen` property
- Add `companion` property:

```swift
"companion": PropertySchema(
    type: "boolean",
    description: "If true, the new agent is a companion of the creator: it won't appear in the agent list, its visibility is linked to the creator, and it will be closed when the creator is closed. Only use this flag if the user has explicitly asked for a companion agent."
)
```

### 3. MCP Tool Handler (`MCPTools.swift`)

In `handleCreateAgent`:
- Replace `splitScreen` extraction with `companion`:
  ```swift
  let companion = arguments["companion"] as? Bool ?? false
  ```
- Pass `companion` instead of `splitScreen` to `mcpService.createAgent()`

### 4. AgentDataProvider Protocol (`MCPService.swift`)

Update the `addAgent` method signature:
```swift
func addAgent(folder:name:avatar:agentType:createdBy:companion:shellCommand:) async -> UUID?
```

Replace `splitScreen: Bool` → `companion: Bool`

### 5. MCPService.createAgent() (`MCPService.swift`)

- Replace `splitScreen` parameter with `companion` in the method signature
- Add validation: if `companion == true`, enforce max 3 companions per owner:
  - Query provider for existing agents where `createdBy == createdBy && isCompanion == true`
  - If count >= 3, return error response
- Pass `companion` to `provider.addAgent()`

### 6. AgentManagerWrapper.addAgent() (`MCPService.swift`)

Replace `splitScreen` logic with `companion` logic:

```swift
func addAgent(..., companion: Bool, ...) async -> UUID? {
    await MainActor.run {
        guard let manager = manager else { return nil }
        guard let newAgentId = manager.addAgent(
            folder: folder, name: name, avatar: avatar,
            agentType: agentType, createdBy: createdBy,
            isCompanion: companion,
            shellCommand: shellCommand
        ) else { return nil }

        // If companion, enter split with owner
        if companion, let creatorId = createdBy {
            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)
        }

        return newAgentId
    }
}
```

### 7. AgentManager.addAgent() (`AgentManager.swift`)

Add `isCompanion` parameter (default `false`):
```swift
func addAgent(..., isCompanion: Bool = false, ...) -> UUID?
```

Set `agent.isCompanion = isCompanion` during Agent creation.

### 8. Sidebar Filtering (`SidebarView.swift`)

Filter out companion agents from the sidebar list:

```swift
ForEach(agentManager.currentWorkspaceAgents.filter { !$0.isCompanion }) { agent in
```

### 9. Cascade Close on Owner Removal (`AgentManager.swift`)

In `removeAgent()`, before removing the owner, find and close all its companions:

```swift
func removeAgent(_ agent: Agent) {
    // Close companions first (if this agent owns any)
    let companions = agents.filter { $0.createdBy == agent.id && $0.isCompanion }
    for companion in companions {
        removeAgent(companion)  // recursive, but companions won't have companions
    }

    // ... existing removal logic
}
```

### 10. Companion Display Linked to Owner

When the owner is selected/displayed in a pane, companions should also be visible. The existing `enterSplitWithNewAgent` already handles putting the companion in a visible pane at creation time. For ongoing visibility linking:

In `selectAgent()` — when the user clicks an owner in the sidebar:
```swift
func selectAgent(_ agentId: UUID) {
    if layoutMode == .single {
        let companions = agents.filter { $0.createdBy == agentId && $0.isCompanion }
        if companions.isEmpty {
            activeAgentIds = [agentId]
        } else {
            // Show owner + companions in split
            activeAgentIds = [agentId] + companions.prefix(3).map { $0.id }
            layoutMode = companions.count == 1 ? .splitVertical :
                         (companions.count >= 3 ? .gridFourPane : .splitVertical)
            focusedPaneIndex = 0
        }
        return
    }
    // ... rest unchanged
}
```

### 11. Agent Navigation

In `selectNextAgent()` and `selectPreviousAgent()` (single mode), skip companion agents since they're not in the sidebar:

```swift
let navigableAgents = workspaceAgents.filter { !$0.isCompanion }
```

### 12. Tests (`MCPServiceTests.swift` + `MockAgentDataProvider.swift`)

- Update `MockAgentDataProvider.addAgent()` signature: `splitScreen` → `companion`
- Update test calls in `MCPServiceTests.swift`: `splitScreen: false` → `companion: false`
- Add new test: companion creation sets `isCompanion = true`
- Add new test: max 3 companions enforcement

## File Changes Summary

| File | Change |
|------|--------|
| `Agent.swift` | Add `isCompanion` property (persisted) |
| `MCPTools.swift` | Replace `splitScreen` → `companion` in tool def + handler |
| `MCPService.swift` | Replace `splitScreen` → `companion` in protocol, service, wrapper. Add max-3 validation |
| `AgentManager.swift` | Add `isCompanion` param to `addAgent()`. Cascade close in `removeAgent()`. Update `selectAgent()` for linked display. Update navigation to skip companions |
| `SidebarView.swift` | Filter `!isCompanion` from sidebar list |
| `MockAgentDataProvider.swift` | Update `addAgent` signature |
| `MCPServiceTests.swift` | Update test calls, add companion tests |

## Commit Strategy

1. **Model + MCP plumbing**: Add `isCompanion` to Agent, update MCP tool def/handler/service/protocol/wrapper — replace `splitScreen` with `companion`
2. **Sidebar + cascade close**: Filter companions from sidebar, cascade close on owner removal
3. **Display linking + navigation**: Linked display in `selectAgent()`, skip companions in navigation
4. **Tests**: Update existing tests, add companion-specific tests
