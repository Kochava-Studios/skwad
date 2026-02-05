import Foundation
import OSLog

/// Central controller for managing a terminal session's lifecycle and state.
///
/// This controller owns all business logic for a terminal session:
/// - Terminal adapter attachment and lifecycle
/// - Command execution (initial command, text injection)
/// - Status state machine (idle → running → idle/error)
/// - Activity detection with debouncing
/// - Idle timeout management
/// - MCP config, registration, and message checking
///
/// Views become dumb adapters that only create the terminal and forward events.
@MainActor
class TerminalSessionController: ObservableObject {

    /// Current session state
    @Published var status: AgentStatus = .idle {
        didSet {
            guard oldValue != status else { return }
            statusDidChange(from: oldValue, to: status)
        }
    }

    /// Unique identifier for this terminal session
    let agentId: UUID

    /// Folder path for this terminal session
    let folder: String

    /// Agent type (claude, aider, etc.)
    let agentType: String

    // MARK: - Dependencies

    private let settings = AppSettings.shared
    private let onStatusChange: (AgentStatus) -> Void
    private let onTitleChange: ((String) -> Void)?

    /// Attached terminal adapter (strong reference - controller owns the adapter)
    private var adapter: TerminalAdapter?

    // MARK: - State

    /// Whether this session is monitoring MCP messages on idle
    private var monitorsMCP: Bool

    private let idleTimer = ManagedTimer()
    private let idleTimeout: TimeInterval
    private var lastNotifiedMessageId: UUID?
    private var isDisposed = false
    private var hasBecomeIdle = false
    private var didStart = false

    // Registration prompt scheduling
    private let registrationTimer = ManagedTimer()
    private var registrationReadyAt: Date?
    private var registrationText: String?
    private var didInjectRegistration = false
    private var idleCount = 0  // Track how many times we've become idle
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kochava.skwad", category: "TerminalSession")

    // MARK: - Initialization

    /// Creates a new terminal session controller
    /// - Parameters:
    ///   - agentId: Unique identifier for the agent
    ///   - folder: Working directory for the terminal
    ///   - agentType: Type of agent (claude, aider, etc.)
    ///   - idleTimeout: Seconds of inactivity before marking idle (default: TimingConstants.idleTimeout)
    ///   - onStatusChange: Callback when status changes
    ///   - onTitleChange: Callback when terminal title changes
    init(
        agentId: UUID,
        folder: String,
        agentType: String,
        idleTimeout: TimeInterval = TimingConstants.idleTimeout,
        onStatusChange: @escaping (AgentStatus) -> Void,
        onTitleChange: ((String) -> Void)? = nil
    ) {
        self.agentId = agentId
        self.folder = folder
        self.agentType = agentType
        self.monitorsMCP = AppSettings.shared.mcpServerEnabled
        self.idleTimeout = idleTimeout
        self.onStatusChange = onStatusChange
        self.onTitleChange = onTitleChange
    }
    
    deinit {
        // ManagedTimer handles automatic cleanup
        isDisposed = true
    }

    // MARK: - Adapter Attachment

    /// Attach a terminal adapter and wire up its events
    /// Call this after creating the terminal view
    func attach(to adapter: TerminalAdapter) {
        self.adapter = adapter

        // Wire adapter events to controller methods
        adapter.onActivity = { [weak self] in
            self?.activityDetected(fromUserInput: false)
        }
        adapter.onUserInput = { [weak self] in
            self?.activityDetected(fromUserInput: true)
        }
        adapter.onReady = { [weak self] in
            self?.terminalDidBecomeReady()
        }
        adapter.onProcessExit = { [weak self] code in
            self?.processDidExit(exitCode: code)
        }
        adapter.onTitleChange = { [weak self] title in
            self?.onTitleChange?(title)
        }

        // Activate the adapter to wire terminal callbacks
        // This must happen after we set the callback properties above
        adapter.activate()
    }

    // MARK: - Terminal Lifecycle

    /// Whether this agent type supports inline registration via command-line
    private var supportsInlineRegistration: Bool {
        TerminalCommandBuilder.supportsInlineRegistration(agentType: agentType)
    }

    /// Build the initialization command for this terminal session
    /// Used by views that need the command at creation time (Ghostty)
    func buildInitializationCommand() -> String {
        // Pass agentId for inline registration if MCP is enabled
        let agentIdForRegistration = settings.mcpServerEnabled ? agentId : nil
        let agentCommand = TerminalCommandBuilder.buildAgentCommand(
            for: agentType,
            settings: settings,
            agentId: agentIdForRegistration
        )
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: folder,
            agentCommand: agentCommand
        )
        Self.logger.info("[skwad][\(String(self.agentId.uuidString.prefix(8)).lowercased())] Command: \(command)")
        return command
    }

    /// Start the terminal session
    /// Behavior depends on adapter's commandMode:
    /// - .atCreation: command already sent, just schedule registration
    /// - .afterReady: send command then schedule registration
    private func start() {
        guard !isDisposed, !didStart, let adapter = adapter else { return }
        didStart = true

        // Send command if adapter expects it after ready
        if adapter.commandMode == .afterReady {
            let command = buildInitializationCommand()
            sendCommand(command)
        }

        // Schedule registration if MCP enabled and agent doesn't support inline registration
        if settings.mcpServerEnabled && !supportsInlineRegistration {
            // Determine initial delay based on agent type
            let agent = availableAgents.first { $0.id == agentType }
            let delay = agent?.needsLongStartup == true
                ? TimingConstants.registrationFirstIdleDelayLong
                : TimingConstants.registrationFirstIdleDelayShort
            scheduleRegistrationPrompt(delay: delay)
        }
    }

    /// Send text to terminal WITHOUT return key
    func sendText(_ text: String) {
        adapter?.sendText(text)
    }

    /// Send return key to terminal
    func sendReturn() {
        adapter?.sendReturn()
    }

    /// Send text to terminal followed by return key
    func sendCommand(_ text: String) {
        adapter?.sendText(text)
        AsyncDelay.dispatch(after: TimingConstants.returnKeyDelay) { [weak self] in
            self?.adapter?.sendReturn()
        }
    }

    /// Inject text into the terminal followed by return (for MCP messages, registration, etc.)
    func injectText(_ text: String) {
        sendCommand(text)
    }

    /// Focus the terminal
    func focus() {
        adapter?.focus()
    }
    
    /// Notify terminal to resize/relayout
    /// Called when the available terminal space changes (e.g., git panel toggle)
    func notifyResize() {
        adapter?.notifyResize()
    }

    // MARK: - Activity Detection

    /// Signals that activity has been detected in the terminal
    /// This resets the idle timer and sets status to running
    /// - Parameter fromUserInput: If true, uses longer timeout for user typing
    private func activityDetected(fromUserInput: Bool) {
        guard !isDisposed else { return }

        // Set status to running
        status = .running

        // Use longer timeout for user input (typing/thinking) vs terminal output
        let timeout = fromUserInput ? TimingConstants.userInputIdleTimeout : idleTimeout

        // Start new timer for idle state (automatically cancels existing timer)
        idleTimer.schedule(after: timeout) { [weak self] in
            self?.markIdle()
        }
    }
    
    /// Signals that the terminal process has exited
    /// - Parameter exitCode: Optional exit code (non-zero implies error)
    private func processDidExit(exitCode: Int32?) {
        guard !isDisposed else { return }

        idleTimer.invalidate()

        if let code = exitCode, code != 0 {
            status = .error
        } else {
            status = .idle
        }
    }
    
    /// Signals that the terminal is ready and rendering
    private func terminalDidBecomeReady() {
        guard !isDisposed else { return }
        status = .running

        // Auto-start when terminal becomes ready
        start()
    }

    /// Schedule the default registration prompt to be injected after delay
    /// Each call cancels any previous timer and starts a new one
    private func scheduleRegistrationPrompt(delay: TimeInterval) {
        guard !isDisposed else { return }
        
        // Set registration text if not already set
        if registrationText == nil {
            registrationText = "You are part of a team of agents called a skwad. Register within the skwad with your agent ID: \(agentId.uuidString). A skwad is made of  high-performing agents who collaborate to achieve complex goals so engage with them: ask for help and in return help them succeed."
        }

        let readyAt = Date().addingTimeInterval(delay)
        registrationReadyAt = readyAt

        // Cancel any existing timer and schedule a new one
        registrationTimer.schedule(after: delay) { [weak self] in
            self?.evaluateRegistrationReadiness()
        }
    }
    
    /// Disposes of the controller, invalidating timers and cleaning up
    func dispose() {
        isDisposed = true
        idleTimer.invalidate()
        registrationTimer.invalidate()

        // Terminate the shell process
        adapter?.terminate()
    }
    
    // MARK: - Private Methods
    
    private func markIdle() {
        guard !isDisposed else { return }
        status = .idle
        
        // Only track idle count if we haven't injected yet
        if !didInjectRegistration {
            idleCount += 1
        }

        hasBecomeIdle = true
        
        // Schedule or reschedule registration based on idle count
        // Skip for agents that support inline registration via CLI arguments
        if !didInjectRegistration && monitorsMCP && !supportsInlineRegistration {
            // Determine delay based on idle count and agent type
            let delay: TimeInterval
            if idleCount == 1 {
                // First idle: check if agent needs long startup time
                let agent = availableAgents.first { $0.id == agentType }
                delay = agent?.needsLongStartup == true 
                    ? TimingConstants.registrationFirstIdleDelayLong 
                    : TimingConstants.registrationFirstIdleDelayShort
            } else {
                // Subsequent idles: always short delay
                delay = TimingConstants.registrationSubsequentIdleDelay
            }
            
            Self.logger.info("[skwad][\(String(self.agentId.uuidString.prefix(8)).lowercased())] Scheduling registration with \(delay)s delay")
            scheduleRegistrationPrompt(delay: delay)
        }
        
        // Check for messages if MCP monitoring is enabled
        if monitorsMCP {
            checkForUnreadMessages()
        }
    }

    private func evaluateRegistrationReadiness() {
        guard !isDisposed, !didInjectRegistration else { return }
        guard let text = registrationText, let readyAt = registrationReadyAt else { return }

        let timeSatisfied = Date() >= readyAt
        let idleSatisfied = hasBecomeIdle

        guard timeSatisfied && idleSatisfied else { return }

        Self.logger.info("[skwad][\(String(self.agentId.uuidString.prefix(8)).lowercased())] Injecting registration prompt")
        didInjectRegistration = true
        
        // Cancel timer and stop tracking idles
        registrationTimer.invalidate()
        registrationText = nil
        registrationReadyAt = nil
        
        injectText(text)
    }
    
    private func statusDidChange(from oldValue: AgentStatus, to newValue: AgentStatus) {
        onStatusChange(newValue)
    }
    
    private func checkForUnreadMessages() {
        Task {
            let latestMessageId = await MCPService.shared.getLatestUnreadMessageId(for: agentId.uuidString)
            
            guard let messageId = latestMessageId else {
                return
            }
            
            await MainActor.run { [weak self] in
                guard let self = self, !self.isDisposed else { return }
                
                // Deduplicate notifications
                if self.lastNotifiedMessageId == messageId {
                    return
                }
                
                Self.logger.info("[skwad][\(String(self.agentId.uuidString.prefix(8)).lowercased())] Notifying about new message")
                self.lastNotifiedMessageId = messageId

                // Inject message notification directly
                self.injectText("Check your inbox for messages from other agents")
            }
        }
    }
}
