# Terminal Controller/View Refactor

## Goal

Clean separation between controller (business logic) and views (dumb wrappers). The controller controls everything:
- Running initial command
- Reacting to terminal events (activity, idle, ready, exit)
- Managing MCP registration and messaging

Views become dumb adapters that only:
- Create the underlying terminal
- Forward events to controller
- Execute text injection when told

## Current State

### What's Good
- `TerminalSessionController` already handles status, idle detection, MCP messaging
- `TerminalCommandBuilder` builds initialization commands
- `TerminalInjector` abstracts text injection

### What's Duplicated
1. **Coordinator pattern** - Both `GhosttyHostView` and `TerminalHostView` have nearly identical Coordinators
2. **Initialization logic** - MCP config writing, command building, registration scheduling in each view
3. **Views know too much** - Views are responsible for command building, MCP config, session creation

## New Architecture

### 1. TerminalAdapter Protocol (NEW)

A dumb interface for terminal views to implement:

```swift
/// Protocol for terminal adapters - abstracts Ghostty/SwiftTerm differences
@MainActor
protocol TerminalAdapter: AnyObject {
    /// Send text to the terminal (no return key)
    func sendText(_ text: String)

    /// Send return key to the terminal
    func sendReturn()

    /// Focus the terminal
    func focus()

    // Events emitted to controller
    var onActivity: (() -> Void)? { get set }
    var onReady: (() -> Void)? { get set }
    var onProcessExit: ((Int32?) -> Void)? { get set }
    var onTitleChange: ((String) -> Void)? { get set }
}
```

### 2. Concrete Adapters

**GhosttyTerminalAdapter** - wraps `GhosttyTerminalView`:
```swift
@MainActor
class GhosttyTerminalAdapter: TerminalAdapter {
    private weak var terminal: GhosttyTerminalView?

    var onActivity: (() -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?

    init(terminal: GhosttyTerminalView) {
        self.terminal = terminal
        // Wire up terminal callbacks to our properties
        terminal.onActivity = { [weak self] in self?.onActivity?() }
        terminal.onReady = { [weak self] in self?.onReady?() }
        terminal.onProcessExit = { [weak self] in self?.onProcessExit?(nil) }
        terminal.onTitleChange = { [weak self] title in self?.onTitleChange?(title) }
    }

    func sendText(_ text: String) {
        terminal?.surface?.sendText(text)
    }

    func sendReturn() {
        guard let surface = terminal?.surface else { return }
        let event = Ghostty.Input.KeyEvent(key: .enter, action: .press, text: "\r")
        surface.sendKeyEvent(event)
    }

    func focus() {
        guard let terminal = terminal else { return }
        terminal.window?.makeFirstResponder(terminal)
    }
}
```

**SwiftTermAdapter** - wraps `ActivityDetectingTerminalView`:
```swift
@MainActor
class SwiftTermAdapter: TerminalAdapter {
    private weak var terminal: ActivityDetectingTerminalView?

    var onActivity: (() -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?  // SwiftTerm ignores this

    init(terminal: ActivityDetectingTerminalView) {
        self.terminal = terminal
        terminal.onActivity = { [weak self] in self?.onActivity?() }
    }

    func sendText(_ text: String) {
        terminal?.send(txt: text)
    }

    func sendReturn() {
        terminal?.send(txt: "\r")  // SwiftTerm just needs the character
    }

    func focus() {
        guard let terminal = terminal else { return }
        terminal.window?.makeFirstResponder(terminal)
    }
}
```

### 3. Enhanced TerminalSessionController

Move ALL business logic here. Controller is created and owned by `AgentManager`.

```swift
@MainActor
class TerminalSessionController: ObservableObject {
    // Existing properties
    @Published var status: AgentStatus = .idle
    let agentId: UUID

    // NEW: adapter reference
    private weak var adapter: TerminalAdapter?

    // Dependencies
    private let settings = AppSettings.shared
    private let onStatusChange: (AgentStatus) -> Void
    private let onTitleChange: ((String) -> Void)?

    // Existing state
    private var idleTimer: Timer?
    private var registrationTimer: Timer?
    // ... rest of existing state ...

    init(
        agentId: UUID,
        onStatusChange: @escaping (AgentStatus) -> Void,
        onTitleChange: ((String) -> Void)? = nil
    ) {
        self.agentId = agentId
        self.onStatusChange = onStatusChange
        self.onTitleChange = onTitleChange
    }

    // MARK: - Adapter Attachment

    /// Attach a terminal adapter and wire up events
    func attach(to adapter: TerminalAdapter) {
        self.adapter = adapter

        // Wire adapter events to controller methods
        adapter.onActivity = { [weak self] in self?.activityDetected() }
        adapter.onReady = { [weak self] in self?.terminalDidBecomeReady() }
        adapter.onProcessExit = { [weak self] code in self?.processDidExit(exitCode: code) }
        adapter.onTitleChange = { [weak self] title in self?.onTitleChange?(title) }
    }

    // MARK: - Terminal Lifecycle

    /// Start the terminal session - called after adapter is attached and ready
    func start(folder: String, agentType: String) {
        // Write MCP config if enabled
        if settings.mcpServerEnabled {
            settings.writeMCPConfig(to: folder)
        }

        // Build and send command
        let agentCommand = settings.getFullCommand(for: agentType)
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: folder,
            agentCommand: agentCommand
        )

        sendCommand(command)

        // Schedule registration if MCP enabled
        if settings.mcpServerEnabled {
            scheduleRegistrationPrompt()
        }
    }

    /// Send text to terminal followed by return
    func sendCommand(_ text: String) {
        adapter?.sendText(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.adapter?.sendReturn()
        }
    }

    /// Inject text (for MCP messages, etc.)
    func injectText(_ text: String) {
        sendCommand(text)
    }

    func focus() {
        adapter?.focus()
    }

    // ... existing methods: activityDetected(), processDidExit(), terminalDidBecomeReady() ...
    // ... existing methods: scheduleRegistrationPrompt(), checkForUnreadMessages() ...
}
```

### 4. Simplified Views

Views become thin wrappers. No more Coordinator needed!

**GhosttyHostView:**
```swift
struct GhosttyHostView: NSViewRepresentable {
    let controller: TerminalSessionController
    let folder: String
    let size: CGSize
    let isActive: Bool

    func makeNSView(context: Context) -> TerminalScrollView {
        // Initialize Ghostty if needed
        if !GhosttyAppManager.shared.isReady {
            GhosttyAppManager.shared.initialize()
        }
        guard let ghosttyApp = GhosttyAppManager.shared.app else {
            fatalError("Ghostty initialization failed")
        }

        // Create terminal WITHOUT command (command sent after ready)
        let terminal = GhosttyTerminalView(
            frame: NSRect(origin: .zero, size: size),
            worktreePath: folder,
            ghosttyApp: ghosttyApp,
            appWrapper: GhosttyAppManager.shared.appWrapper,
            paneId: controller.agentId.uuidString,
            command: nil  // No command at init!
        )

        // Create adapter and attach to controller
        let adapter = GhosttyTerminalAdapter(terminal: terminal)
        controller.attach(to: adapter)

        return TerminalScrollView(contentSize: size, surfaceView: terminal)
    }

    func updateNSView(_ nsView: TerminalScrollView, context: Context) {
        if nsView.frame.size != size {
            nsView.frame = CGRect(origin: .zero, size: size)
            nsView.needsLayout = true
        }
        if isActive {
            controller.focus()
        }
    }

    // No Coordinator needed!
}
```

**TerminalHostView:**
```swift
struct TerminalHostView: NSViewRepresentable {
    let controller: TerminalSessionController
    let folder: String
    let isActive: Bool

    @ObservedObject private var settings = AppSettings.shared

    func makeNSView(context: Context) -> ActivityDetectingTerminalView {
        let terminal = ActivityDetectingTerminalView(frame: .zero)
        applySettings(to: terminal)

        // Start shell
        let shell = TerminalCommandBuilder.getDefaultShell()
        terminal.startProcess(executable: shell, args: ["-i", "-l"], environment: nil, execName: nil)

        // Create adapter and attach to controller
        let adapter = SwiftTermAdapter(terminal: terminal)
        controller.attach(to: adapter)

        // SwiftTerm needs delegate for process exit
        terminal.processDelegate = context.coordinator

        return terminal
    }

    func updateNSView(_ nsView: ActivityDetectingTerminalView, context: Context) {
        applySettings(to: nsView)
        if isActive {
            controller.focus()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    // Minimal coordinator just for SwiftTerm's delegate protocol
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let controller: TerminalSessionController

        init(controller: TerminalSessionController) {
            self.controller = controller
        }

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            controller.processDidExit(exitCode: exitCode)
        }

        // Other delegate methods - no-op
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
```

### 5. AgentManager Changes

AgentManager owns the controllers (not terminals):

```swift
@MainActor
class AgentManager: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var selectedAgentId: UUID?

    // Controllers keyed by agent ID
    private var controllers: [UUID: TerminalSessionController] = [:]

    // MARK: - Controller Management

    func getController(for agentId: UUID) -> TerminalSessionController? {
        controllers[agentId]
    }

    func createController(for agent: Agent) -> TerminalSessionController {
        let controller = TerminalSessionController(
            agentId: agent.id,
            onStatusChange: { [weak self] status in
                self?.updateStatus(for: agent.id, status: status)
            },
            onTitleChange: { [weak self] title in
                self?.updateTitle(for: agent.id, title: title)
            }
        )
        controllers[agent.id] = controller
        return controller
    }

    func removeController(for agentId: UUID) {
        controllers[agentId]?.dispose()
        controllers.removeValue(forKey: agentId)
    }

    // Simplified injection - delegates to controller
    func injectText(_ text: String, for agentId: UUID) {
        controllers[agentId]?.injectText(text)
    }

    // ... rest of AgentManager ...
}
```

### 6. AgentTerminalView Changes

Create controller and pass it to views:

```swift
struct AgentTerminalView: View {
    @EnvironmentObject var agentManager: AgentManager
    @ObservedObject private var settings = AppSettings.shared
    let agent: Agent

    @State private var controller: TerminalSessionController?

    var body: some View {
        VStack(spacing: 0) {
            // Header...

            // Terminal view - unified interface
            if let controller = controller {
                if settings.terminalEngine == "ghostty" {
                    GhosttyTerminalWrapperView(
                        controller: controller,
                        folder: agent.folder,
                        agentType: agent.agentType,
                        isActive: isActive
                    )
                } else {
                    SwiftTermTerminalWrapperView(
                        controller: controller,
                        folder: agent.folder,
                        agentType: agent.agentType,
                        isActive: isActive
                    )
                }
            }
        }
        .onAppear {
            controller = agentManager.createController(for: agent)
        }
        .onDisappear {
            if let id = controller?.agentId {
                agentManager.removeController(for: id)
            }
        }
    }
}
```

## File Changes Summary

| File | Change |
|------|--------|
| `Services/TerminalAdapter.swift` | NEW - Protocol + GhosttyTerminalAdapter + SwiftTermAdapter |
| `Services/TerminalSessionController.swift` | Enhanced - add adapter attachment, start(), focus() |
| `Services/TerminalInjector.swift` | DELETE - logic moved to adapters |
| `Views/Terminal/GhosttyHostView.swift` | Simplified - remove Coordinator, use controller |
| `Views/Terminal/TerminalHostView.swift` | Simplified - minimal Coordinator for delegate only |
| `Views/Terminal/AgentTerminalView.swift` | Updated - create/manage controller |
| `Models/AgentManager.swift` | Changed - own controllers instead of terminals |
| `GhosttyTerminal/GhosttyTerminalView.swift` | Minor - command becomes optional (already is) |

## Command Execution Timing

Both engines now use the same flow:
1. Terminal created (Ghostty without command, SwiftTerm with shell only)
2. Adapter attached to controller
3. When `onReady` fires, controller calls `start(folder:agentType:)`
4. Controller builds command and calls `adapter.sendText()` + `adapter.sendReturn()`

This unifies the timing and eliminates the Ghostty `initial_input` special case.

## Commit Strategy

1. **Add TerminalAdapter protocol and implementations**
   - Create `Services/TerminalAdapter.swift` with protocol + both adapters
   - Update `Skwad.xcodeproj` to include new file
   - No breaking changes yet

2. **Enhance TerminalSessionController**
   - Add `attach(to:)`, `start()`, `sendCommand()`, `focus()`
   - Keep existing methods working

3. **Simplify GhosttyHostView**
   - Remove Coordinator
   - Accept controller, create adapter, attach
   - Pass `command: nil` to GhosttyTerminalView

4. **Simplify TerminalHostView**
   - Minimal Coordinator for delegate only
   - Accept controller, create adapter, attach

5. **Update AgentManager**
   - Own controllers instead of terminals
   - Remove terminal-specific code

6. **Update AgentTerminalView**
   - Create controller on appear
   - Pass to terminal views

7. **Delete TerminalInjector.swift**
   - Remove file and update `Skwad.xcodeproj`
   - Logic now in adapters

8. **Clean up and test**

## Key Design Decisions

1. **Controller owned by AgentManager** - Survives view recreation, single source of truth
2. **Unified command timing** - Both engines send command after ready via adapter
3. **Title change in protocol** - SwiftTerm ignores it, but interface is consistent
4. **Weak adapter reference** - Controller doesn't retain view
5. **No TerminalInjector** - Adapters handle injection directly

## Testing Checklist

- [ ] Create agent with Ghostty - verify command runs after ready
- [ ] Create agent with SwiftTerm - verify command runs after ready
- [ ] Switch between agents - verify focus works
- [ ] MCP registration - verify prompt injected when idle
- [ ] MCP messaging - verify check messages works
- [ ] Restart agent - verify new controller created
- [ ] Remove agent - verify cleanup
- [ ] Status transitions - verify idle/running/error states

## Implementation Notes (Post-Completion)

### Key Learnings

1. **Auto-start on ready**: Controller's `start()` is called automatically in `terminalDidBecomeReady()`. This unifies both terminal engines since they both fire `onReady` when the terminal is initialized.

2. **Three text injection methods**:
   - `sendText()` - send text without return (for voice input partial text)
   - `sendReturn()` - send just the return key
   - `injectText()` / `sendCommand()` - send text + return (for MCP messages, commands)

3. **SwiftTerm needs explicit ready signal**: Unlike Ghostty which has a native `onReady` callback, SwiftTerm needs the adapter to call `notifyReady()` after a brief delay for shell initialization.

4. **MCPService simplification**: Removed `injectCheckMessages()` from protocol, replaced with simple `injectText()` that the controller uses.

5. **Terminal reference still needed**: AgentManager still keeps weak terminal references for Ghostty's `forceRefresh()` on window resize. This is separate from controller ownership.

### Files Changed
- `Services/TerminalAdapter.swift` - NEW: protocol + 2 adapters
- `Services/TerminalSessionController.swift` - enhanced with attach/start/inject
- `Services/TerminalInjector.swift` - DELETED
- `Views/Terminal/GhosttyHostView.swift` - simplified, no Coordinator
- `Views/Terminal/TerminalHostView.swift` - minimal Coordinator
- `Views/Terminal/AgentTerminalView.swift` - creates controller on appear
- `Models/AgentManager.swift` - owns controllers, delegates text injection
- `MCP/MCPService.swift` - simplified AgentDataProvider protocol
