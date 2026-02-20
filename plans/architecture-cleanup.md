# Architecture Cleanup: Rename MCPService + Move Message Checking

## Goal

Clean up the architecture so that:
1. `MCPService` is renamed to `AgentCoordinator` to reflect its real role
2. `TerminalSessionController` no longer accesses `MCPService`/`AgentCoordinator` directly — the "check unread messages on idle" flow goes through `AgentManager`
3. AgentManager is the single brain that everything routes through

## Phase 1: Move `checkForUnreadMessages` to AgentManager

**Why first:** This removes the `MCPService.shared` dependency from `TerminalSessionController` before the rename, so the rename has one less file to touch.

### Steps

1. **Add callback to TerminalSessionController**
   - Add `onIdle: (() -> Void)?` callback property (alongside existing `onStatusChange`)
   - Call it from `markIdle()` and `inputProtectionDidExpire()` — replacing the direct `checkForUnreadMessages()` calls
   - Remove `checkForUnreadMessages()` method entirely
   - Remove `lastNotifiedMessageId` property
   - Remove `monitorsMCP` property
   - Remove `import` / reference to `MCPService`

2. **Wire the callback in AgentManager.createController()**
   - Add `onIdle` closure that calls a new `checkForUnreadMessages(for: agent.id)` method
   - The new method on AgentManager:
     - Checks `AppSettings.shared.mcpServerEnabled` (replaces the old `monitorsMCP`)
     - Checks the agent is not a shell
     - Calls `MCPService.shared.getLatestUnreadMessageId()`
     - Tracks `lastNotifiedMessageId` per agent (new dictionary on AgentManager)
     - Deduplicates and calls `injectText()` if there's a new message

3. **Handle input protection edge case**
   - `inputProtectionDidExpire()` currently calls `checkForUnreadMessages()` too
   - Add an `onInputProtectionExpired: (() -> Void)?` callback or reuse `onIdle`
   - Wire it the same way

4. **Update tests**
   - Update any `TerminalSessionController` tests that reference message checking
   - Add test for `AgentManager.checkForUnreadMessages()` if feasible

**Commit:** `refactor: move unread message checking from TerminalSessionController to AgentManager`

## Phase 2: Rename MCPService → AgentCoordinator

### Steps

1. **Rename the file**
   - `Skwad/MCP/MCPService.swift` → `Skwad/MCP/AgentCoordinator.swift`

2. **Rename the actor**
   - `actor MCPService` → `actor AgentCoordinator`
   - `MCPService.shared` → `AgentCoordinator.shared`
   - `MCPServiceProtocol` → `AgentCoordinatorProtocol`

3. **Update all production code references** (after Phase 1, these are the remaining ones):
   - `MCPServer.swift` — property type + init parameter (2 refs)
   - `MCPTools.swift` — property type + init parameter (2 refs)
   - `ClaudeHookHandler.swift` — property type (1 ref)
   - `AgentManager.swift` — `.shared.unregisterAgent()` calls (2 refs)
   - `SkwadApp.swift` — `.shared.setAgentManager()` call (1 ref)
   - `MCPMessageStore.swift` — comment only (1 ref)

4. **Update test files:**
   - `MCPServiceTests.swift` → rename to `AgentCoordinatorTests.swift`
   - `ClaudeHookHandlerTests.swift` — property type (1 ref)
   - Update all `MCPService.shared` references in tests (~32 occurrences)

5. **Update Xcode project file**
   - File references in `project.pbxproj` for the renamed files

6. **Update documentation:**
   - `AGENTS.md` — 4 references to MCPService

**Commit:** `refactor: rename MCPService to AgentCoordinator`

## Phase 3: Verify + cleanup

1. Build and run
2. Run all tests
3. Manual smoke test: create agent, send message between agents, verify delivery on idle
4. Clean up any stale plan references (optional, low priority)

**Commit:** (only if fixups needed)

## Files touched (summary)

| File | Phase 1 | Phase 2 |
|------|---------|---------|
| `TerminalSessionController.swift` | Major edit | - |
| `AgentManager.swift` | Add method + callback | Update 2 refs |
| `MCPService.swift` → `AgentCoordinator.swift` | - | Rename file + class |
| `MCPServer.swift` | - | Update type refs |
| `MCPTools.swift` | - | Update type refs |
| `ClaudeHookHandler.swift` | - | Update type ref |
| `SkwadApp.swift` | - | Update 1 ref |
| `MCPMessageStore.swift` | - | Update comment |
| `AGENTS.md` | - | Update 4 refs |
| `project.pbxproj` | - | Update file refs |
| Tests | Minor | Rename + update refs |

## Risk assessment

- **Low risk**: This is purely a refactor — no behavior changes
- **Phase 1** is the trickier part (moving logic between classes)
- **Phase 2** is mechanical (find-and-replace rename)
- Both phases have a commit boundary so we can roll back independently
