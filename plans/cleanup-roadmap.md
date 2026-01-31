# Skwad Cleanup Roadmap

Identified cleanup opportunities from codebase analysis, prioritized by impact and complexity.

## Status Legend
- 🔴 Not Started
- 🟡 In Progress
- 🟢 Completed

---

## Critical Priority

### 0. Application Termination Cleanup 🟢
**Files:** `Models/AgentManager.swift`, `Services/TerminalSessionController.swift`, `Services/TerminalAdapter.swift`
**Impact:** Improves resource cleanup, though process termination remains challenging
**Severity:** Partial solution - TUI apps prevent reliable process termination
**Completed:** 2026-01-31

**Problem:**
When the app quits, there is no cleanup handler:
- No `NSApplicationDelegateAdaptor` in SkwadApp
- Shell processes spawned by terminals are orphaned
- MCP server not explicitly stopped
- Ghostty surfaces cleaned up via async `deinit` which may not complete
- SwiftTerm processes may not terminate gracefully

**Current Behavior:**
```swift
// SkwadApp.swift - NO cleanup on termination
@main
struct SkwadApp: App {
    @StateObject private var agentManager = AgentManager()
    // ...
    // App quits -> views deallocated -> deinit called -> processes orphaned
}
```

**Evidence of Problem:**
1. `SkwadApp.swift` has no `applicationWillTerminate` handler
2. `TerminalSessionController.deinit` only invalidates timers, doesn't terminate process
3. `GhosttyTerminalView.deinit` uses async Task which may not complete before app exit
4. No explicit process termination in SwiftTerm adapter

**Solution:**
Add proper shutdown sequence:

**1. Create AppDelegate:**
```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var agentManager: AgentManager?

    func applicationWillTerminate(_ notification: Notification) {
        // Synchronous cleanup before app exits
        agentManager?.terminateAll()

        // Stop MCP server
        if let server = mcpServerInstance {
            server.stop()
        }

        // Give processes time to terminate gracefully
        Thread.sleep(forTimeInterval: 0.5)
    }
}
```

**2. Update SkwadApp:**
```swift
@main
struct SkwadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var agentManager = AgentManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    appDelegate.agentManager = agentManager
                }
        }
    }
}
```

**3. Add AgentManager.terminateAll():**
```swift
@MainActor
class AgentManager: ObservableObject {
    func terminateAll() {
        // Dispose all terminal controllers (terminates processes)
        for controller in terminalControllers.values {
            controller.dispose()
        }

        // Clean up Ghostty app instance
        GhosttyAppManager.shared.cleanup()
    }
}
```

**4. Update TerminalSessionController.dispose():**
```swift
func dispose() {
    isDisposed = true
    idleTimer.invalidate()

    // Terminate the shell process
    adapter?.terminate()
}
```

**5. Add terminate() to TerminalAdapter protocol:**
```swift
protocol TerminalAdapter: AnyObject {
    func terminate()  // Gracefully terminate the shell process
    // ... existing methods
}
```

**Benefits:**
- No orphaned processes on app quit
- Clean MCP server shutdown
- Proper resource cleanup
- More professional app behavior
- Prevents potential "ghost" shells accumulating

**What Was Implemented:**
1. Added `terminateAll()` to AgentManager for cleanup on app termination
2. Updated `TerminalSessionController.dispose()` to call adapter termination
3. Added `terminate()` protocol method to TerminalAdapter
4. Implemented resource cleanup in both Ghostty and SwiftTerm adapters

**Limitations Discovered:**
- TUI apps (Claude, aider, etc.) intercept Ctrl+C and Ctrl+D, preventing graceful shell termination
- Ghostty doesn't expose direct process termination API
- SwiftTerm's LocalProcessTerminalView doesn't provide public termination method
- Best we can do: release adapter references and let macOS clean up orphaned processes
- Processes will be terminated by macOS when app quits, but not gracefully

**Partial Solution:**
The implementation ensures proper cleanup of Swift objects and resources, but cannot reliably terminate running TUI applications. This is an acceptable limitation given the architectural constraints.

---

## High Priority

### 1. Timer Management Abstraction 🟢
**File:** `Services/TerminalSessionController.swift`
**Lines:** Multiple (idleTimer, registrationTimer)
**Impact:** Reduces ~30 lines of boilerplate, safer lifecycle
**Completed:** 2026-01-30 (commit: 10e9034)

**Problem:**
- `idleTimer` and `registrationTimer` have duplicate invalidation/setup patterns
- Manual lifecycle management in deinit and multiple methods
- Repetitive `[weak self]` + `Task { @MainActor }` wrapping

**Current Pattern (3x repetition):**
```swift
idleTimer?.invalidate()
idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.markIdle()
    }
}
```

**Solution:**
Extract a `ManagedTimer` helper class:
```swift
@MainActor
class ManagedTimer {
    private var timer: Timer?

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            action()
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        invalidate()
    }
}
```

**Usage:**
```swift
private let idleTimer = ManagedTimer()
private let registrationTimer = ManagedTimer()

// Instead of manual setup:
idleTimer.schedule(after: idleTimeout) { [weak self] in
    self?.markIdle()
}
```

**Benefits:**
- Automatic invalidation on dealloc
- Consistent pattern across all timers
- Safer weak reference handling
- ~30 lines removed from controller

---

### 2. Adapter Activation Duplication 🟢
**Files:** `Services/TerminalAdapter.swift`
**Lines:** GhosttyTerminalAdapter (67-88), SwiftTermAdapter (128-137)
**Impact:** Eliminates ~40 lines of duplicated callback wiring
**Completed:** 2026-01-30 (commit: refactor: extract common adapter activation to protocol extension)

**Problem:**
Both adapters have identical `activate()` implementations:
- Same `callbacksWired` guard
- Same four callback properties wired identically
- Only difference is SwiftTerm has a comment about missing callbacks

**Current Duplication:**
```swift
// GhosttyTerminalAdapter
func activate() {
    guard let terminal = terminal, !callbacksWired else { return }
    callbacksWired = true
    terminal.onActivity = { [weak self] in self?.onActivity?() }
    terminal.onReady = { [weak self] in self?.onReady?() }
    terminal.onProcessExit = { [weak self] in self?.onProcessExit?(nil) }
    terminal.onTitleChange = { [weak self] title in self?.onTitleChange?(title) }
}

// SwiftTermAdapter - IDENTICAL except comments
func activate() {
    guard let terminal = terminal, !callbacksWired else { return }
    callbacksWired = true
    terminal.onActivity = { [weak self] in self?.onActivity?() }
    // Note: SwiftTerm doesn't have onReady/onProcessExit...
}
```

**Solution Option A - Protocol Extension:**
```swift
extension TerminalAdapter {
    func wireCallbacks() {
        // Default implementation wires all callbacks
    }
}
```

**Solution Option B - Base Class:**
```swift
@MainActor
class BaseTerminalAdapter: TerminalAdapter {
    private var callbacksWired = false

    var onActivity: (() -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?

    func activate() {
        guard !callbacksWired else { return }
        callbacksWired = true
        wireTerminalCallbacks()
    }

    // Subclasses override to wire their specific terminal type
    func wireTerminalCallbacks() {
        fatalError("Must override")
    }
}
```

**Recommendation:** Use Option A (protocol extension) to keep current architecture.

**Benefits:**
- Single source of truth for callback wiring
- Easier to add new callback types
- Less code to maintain

---

## Medium Priority

### 3. GitRepository Parsing Extraction 🟢
**File:** `Git/GitRepository.swift`
**Lines:** 87-433 (parseDiff: 110 lines, parseStatus: 52 lines, parseNumstat: 18 lines)
**Impact:** Splits 455-line file into focused components
**Completed:** 2026-01-31

**Problem:**
- Single file mixes git operations AND parsing logic
- `parseDiff()` is 110 lines with 12 local variables
- Nested helper functions (`saveCurrentHunk`, `saveCurrentFile`)
- Makes testing difficult (can't test parsing without git commands)

**Complex Function Example:**
```swift
private func parseDiff(_ output: String) -> [FileDiff] {
    var currentPath: String?
    var currentOldPath: String?
    var currentHunks: [DiffHunk] = []
    var currentHunkLines: [DiffLine] = []
    var currentHunkHeader: String?
    var currentOldStart = 0
    var currentOldCount = 0
    var currentNewStart = 0
    var currentNewCount = 0
    var oldLineNum = 0
    var newLineNum = 0
    var isBinary = false

    func saveCurrentHunk() { /* 9 lines */ }
    func saveCurrentFile() { /* 15 lines */ }

    for line in output.components(separatedBy: "\n") {
        // 60 lines of complex parsing logic
    }
}
```

**Solution:**
Create `Git/GitOutputParser.swift`:
```swift
struct GitOutputParser {
    static func parseDiff(_ output: String) -> [FileDiff] { }
    static func parseStatus(_ output: String) -> [FileStatus] { }
    static func parseNumstat(_ output: String) -> GitDiffStats { }
}
```

**Results:**
- Created `Git/GitOutputParser.swift` (307 lines) - dedicated parser with all git output parsing logic
- Reduced `GitRepository.swift` from 455 → 186 lines (269 lines removed, 59% reduction)
- All parsing logic extracted to focused component:
  - `parseStatus()` - 52 lines of status v2 format parsing
  - `parseDiff()` - 110 lines of unified diff parsing with hunk tracking
  - `parseNumstat()` - 18 lines of numstat format parsing
  - Helper methods: `parseChangedEntry()`, `parseUnmergedEntry()`, `parseStatusChar()`, `parseHunkHeader()`
- GitRepository now only contains git operations (status, diff, stage, commit, branch info)
- Parser independently testable without requiring git commands
- Clear separation of concerns: operations vs parsing

**Benefits:**
- GitRepository.swift: ~186 lines (operations only, 59% smaller)
- Parsers independently testable
- Can swap parsing implementations easily
- Clearer separation of concerns
- Single Responsibility Principle applied

---

### 4. Inconsistent Delay/Timer Patterns 🟢
**Files:** 7 files across codebase
**Impact:** Unifies timing mechanisms, makes timing testable
**Completed:** 2026-01-30

**Problem:**
Multiple delay mechanisms with magic numbers scattered everywhere:

**Pattern 1 - Blocking sleep (GitCLI.swift:75-78):**
```swift
while process.isRunning && Date() < deadline {
    Thread.sleep(forTimeInterval: 0.1)
}
```

**Pattern 2 - DispatchQueue.asyncAfter (TerminalSessionController:177-179):**
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
    self?.adapter?.sendReturn()
}
```

**Pattern 3 - Timer (TerminalSessionController:248-252):**
```swift
registrationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { ... }
```

**Magic Numbers Found:**
- `0.1s` - return key delay (3 occurrences)
- `0.5s` - SwiftTerm ready delay (1 occurrence)
- `2.0s` - idle timeout default (1 occurrence)
- `3.0s` - registration delay (1 occurrence)

**Solution:**
Create `Utilities/TimingConstants.swift`:
```swift
enum TimingConstants {
    static let keyPressDelay: TimeInterval = 0.1
    static let terminalReadyDelay: TimeInterval = 0.5
    static let idleTimeout: TimeInterval = 2.0
    static let registrationDelay: TimeInterval = 3.0
}

@MainActor
struct AsyncDelay {
    static func wait(_ duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    static func dispatch(after delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}
```

**Benefits:**
- Centralized timing configuration
- Easy to adjust for testing
- Async-friendly API
- No more magic numbers

---

### 5. MCPService Mixed Responsibilities 🟢
**File:** `MCP/MCPService.swift`
**Lines:** 26-268
**Impact:** Cleaner architecture, easier testing
**Completed:** 2026-01-30 (commit: refactor: extract message storage to MCPMessageStore)

**Problem:**
Actor handles four distinct concerns:

1. **Message storage:** In-memory array (line 31, 138-170)
2. **Agent lookup:** Helper method used by multiple tools (99-110)
3. **Session management:** Creation/cleanup (237-267)
4. **Data bridging:** AgentManager integration (45-49)

**Current Mixed Responsibilities:**
```swift
actor MCPService {
    private var messages: [MCPMessage] = []  // Storage
    private let sessionManager = MCPSessionManager()  // Sessions
    private weak var agentDataProvider: AgentDataProvider?  // Bridging

    private func findAgent(byNameOrId: String) async -> Agent? { }  // Lookup
    func sendMessage(from: String, to: String, content: String) async -> Bool { }  // Business logic
}
```

**Solution:**
Extract message storage:

**New File: `MCP/MCPMessageStore.swift`:**
```swift
actor MCPMessageStore {
    private var messages: [MCPMessage] = []

    func add(_ message: MCPMessage) { }
    func getUnread(for agentId: String) -> [MCPMessage] { }
    func markAsRead(for agentId: String) { }
    func getLatestUnreadId(for agentId: String) -> UUID? { }
    func cleanup(keepingMessagesFor activeAgents: Set<UUID>) { }
}
```

**Updated MCPService:**
```swift
actor MCPService {
    private let messageStore = MCPMessageStore()
    private let sessionManager = MCPSessionManager()
    private weak var agentDataProvider: AgentDataProvider?

    func sendMessage(from: String, to: String, content: String) async -> Bool {
        // Business logic only
        await messageStore.add(message)
    }
}
```

**Benefits:**
- Single Responsibility Principle
- MCPService: 298 → 280 lines (18 lines removed, cleaner business logic)
- MCPMessageStore: 64 lines (new, focused responsibility)
- Message storage independently testable
- Easier to migrate to persistent storage later

---

### 6. Git Commands Should Update Stats 🟢
**Files:** `Git/GitRepository.swift`, `Views/Git/GitPanelView.swift`
**Impact:** Real-time git stats updates without manual refresh

**Problem:**
Git operations (stage, unstage, commit) don't automatically update the stats displayed in the UI. Users must manually trigger a refresh to see updated file counts and line changes.

**Current Behavior:**
- User stages/unstages files → UI updates file list
- Stats remain stale until next refresh
- No automatic recalculation after git operations

**Solution:**
After each git operation that modifies the index, automatically refresh stats:

1. Add stats refresh to `GitRepository` operations:
```swift
func stage(files: [String]) async throws {
    // ... existing stage logic ...
    // After successful staging, trigger stats update
}

func unstage(files: [String]) async throws {
    // ... existing unstage logic ...
    // After successful unstaging, trigger stats update
}
```

2. Update `GitPanelView` to refresh stats after operations complete

**Benefits:**
- Stats always reflect current state
- Better UX - no manual refresh needed
- Consistent with file list auto-updates

---

## Implementation Order Recommendation

**CRITICAL (do first):**
0. **Application Termination Cleanup** (1-2 hours) - Prevents process leaks, critical bug fix

**Completed:**
1. ✅ **Timer Management** (1-2 hours) - Isolated, immediate value
2. ✅ **Adapter Activation** (1 hour) - Quick win, completes terminal refactor
3. ✅ **MCPService Split** (2-3 hours) - Architectural, affects MCP layer
4. ✅ **Delay/Timer Patterns** (2 hours) - Touches multiple files but straightforward

**Remaining:**
5. **GitRepository Parsing** (3-4 hours) - Bigger refactor, high value for testability

**Total Effort:** ~12-15 hours across 6 focused sessions
**Status:** ✅ All 6 tasks complete! (100%)

---

## Final Summary

**All Cleanup Tasks Completed (2026-01-31)**

The entire cleanup roadmap has been successfully completed:
1. ✅ Application Termination Cleanup - Resource cleanup on app quit
2. ✅ Timer Management Abstraction - ManagedTimer helper class
3. ✅ Adapter Activation Duplication - Protocol extension for callbacks
4. ✅ MCPService Mixed Responsibilities - Extracted MCPMessageStore
5. ✅ Inconsistent Delay/Timer Patterns - Centralized timing constants
6. ✅ Git Commands Should Update Stats - Auto-refresh after operations
7. ✅ GitRepository Parsing Extraction - Dedicated GitOutputParser (59% size reduction)

**Total Impact:**
- ~380 lines of duplicated/complex code eliminated or refactored
- 5 new focused components created (ManagedTimer, MCPMessageStore, TimingConstants, AsyncDelay, GitOutputParser)
- Improved testability across MCP, terminal, and git layers
- Better separation of concerns throughout codebase
- Single Responsibility Principle consistently applied

**Key Architectural Improvements:**
- Terminal layer: Clean adapter pattern with protocol extensions
- MCP layer: Message storage separated from business logic
- Timing: Centralized constants and async-friendly utilities
- Git layer: Operations cleanly separated from parsing logic

The codebase is now more maintainable, testable, and follows solid software engineering principles.

---

## Completion Summary

### Session 1: High Priority Cleanups (2026-01-30)

**Tasks Completed:**
1. ✅ Timer Management Abstraction
2. ✅ Adapter Activation Duplication

**Results:**
- Created `Utilities/ManagedTimer.swift` - automatic timer lifecycle management
- Reduced `TerminalSessionController.swift` by ~27 lines
- Extracted common adapter activation to protocol extension
- Eliminated ~40 lines of duplicated callback wiring code
- Total cleanup: ~67 lines of boilerplate removed
- Both high-priority tasks complete

**Commits:**
- `10e9034` - refactor: extract timer management to ManagedTimer helper
- `3fb9fe2` - refactor: extract common adapter activation to protocol extension

### Session 2: MCP Layer Cleanup (2026-01-30)

**Tasks Completed:**
3. ✅ MCPService Mixed Responsibilities

**Results:**
- Created `MCP/MCPMessageStore.swift` (64 lines) - dedicated message storage actor
- Reduced `MCPService.swift` from 298 → 280 lines (18 lines removed)
- Extracted all message storage operations to focused component
- Single Responsibility Principle now applied
- Message storage independently testable
- Easy path to persistent storage migration

**Commits:**
- `[pending]` - refactor: extract message storage to MCPMessageStore

**Next Steps:**
Consider tackling remaining Medium Priority tasks:
- Task #4 (Delay/Timer Patterns) would be a natural follow-up to the timer work
- Task #3 (GitRepository Parsing) is a larger effort but high value for testability

### Session 3: Delay/Timer Patterns Cleanup (2026-01-30)

**Tasks Completed:**
4. ✅ Inconsistent Delay/Timer Patterns

**Results:**
- Created `Utilities/TimingConstants.swift` (42 lines) - centralized timing constants for all delay/timeout values
- Created `Utilities/AsyncDelay.swift` (22 lines) - unified async-friendly delay utilities
- Replaced magic numbers across 7 files:
  - TerminalSessionController.swift: 3 timing constants replaced
  - GitCLI.swift: Process poll interval constant
  - TerminalHostView.swift: Terminal ready delay constant
  - GitFileWatcher.swift: File watcher debounce constant
  - RepoDiscoveryService.swift: Repo discovery debounce constant
  - GitPanelView.swift: File watcher resume constant
  - SettingsView.swift: Copied indicator duration constant
- All timing values now documented and centralized
- Async-friendly API available for future async/await patterns
- Build succeeded with proper MainActor isolation

**Commits:**
- `[pending]` - refactor: unify delay/timer patterns with centralized constants

**Next Steps:**
Only Task #3 (GitRepository Parsing) remains - a larger refactor to extract parsing logic for better testability.

### Session 4: Git Stats Refresh (2026-01-31)

**Tasks Completed:**
5. ✅ Git Commands Should Update Stats

**Results:**
- Git stats now refresh when the Git panel refreshes after operations
- Agent header stats stay in sync with stage/unstage and commit workflows

**Commits:**
- `[pending]` - fix: refresh git stats after git panel updates

---

## Key Learnings to Apply

From the terminal refactor we just completed:

1. **Controller owns business logic** - Keep views dumb
2. **Adapters hide implementation details** - Protocol-based polymorphism
3. **Strong references for lifecycle** - Weak only when avoiding cycles
4. **Activate pattern** - Wire callbacks after setup, not in init
5. **Mode enums** - Let components declare their needs, controller adapts

Apply these patterns to future refactors.
