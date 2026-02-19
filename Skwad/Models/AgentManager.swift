import Foundation
import SwiftUI
import Observation

enum LayoutMode: String, Codable {
    case single
    case splitVertical   // left | right
    case splitHorizontal // top / bottom
    case threePane       // left half full-height | right top / right bottom
    case gridFourPane    // 4-pane grid (up to 4 agents)

    var paneCount: Int {
        switch self {
        case .single: return 1
        case .splitVertical, .splitHorizontal: return 2
        case .threePane: return 3
        case .gridFourPane: return 4
        }
    }
}

// Weak wrapper for terminal references to avoid retain cycles
private class WeakTerminalRef {
    weak var terminal: GhosttyTerminalView?
    init(_ terminal: GhosttyTerminalView) {
        self.terminal = terminal
    }
}

@Observable
@MainActor
final class AgentManager {
    // All agents across all workspaces
    var agents: [Agent] = []

    // Workspaces
    var workspaces: [Workspace] = []
    var currentWorkspaceId: UUID?


    private let settings = AppSettings.shared

    // Terminal references for each agent (keyed by agent ID)
    // Uses weak references to avoid retain cycles with SwiftUI view lifecycle
    private var terminals: [UUID: WeakTerminalRef] = [:]

    // Controllers for each agent (keyed by agent ID)
    private var controllers: [UUID: TerminalSessionController] = [:]

    // Serial queue for git stats refresh to avoid thundering herd at startup
    private let gitStatsQueue = DispatchQueue(label: "AgentManager.gitStats", qos: .utility)

    init() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        if settings.restoreLayoutOnLaunch {
            agents = settings.loadSavedAgents()
            workspaces = settings.loadWorkspaces()

            // Migration: if we have agents but no workspaces, create default "Skwad" workspace
            if !agents.isEmpty && workspaces.isEmpty {
                let defaultWorkspace = Workspace.createDefault(withAgentIds: agents.map { $0.id })
                workspaces = [defaultWorkspace]
                currentWorkspaceId = defaultWorkspace.id
                saveWorkspaces()
            } else if let savedCurrentId = settings.currentWorkspaceId,
                      workspaces.contains(where: { $0.id == savedCurrentId }) {
                currentWorkspaceId = savedCurrentId
            } else {
                currentWorkspaceId = workspaces.first?.id
            }

            // Restore companion layout for the active agent
            if let activeId = activeAgentIds.first {
                applyCompanionLayout(for: activeId)
            }
        }
    }

    // MARK: - Current Workspace

    var currentWorkspace: Workspace? {
        get {
            guard let id = currentWorkspaceId else { return nil }
            return workspaces.first { $0.id == id }
        }
        set {
            guard let workspace = newValue,
                  let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
            workspaces[index] = workspace
            saveWorkspaces()
        }
    }

    /// Agents in the current workspace
    var currentWorkspaceAgents: [Agent] {
        guard let workspace = currentWorkspace else { return [] }
        return workspace.agentIds.compactMap { id in agents.first { $0.id == id } }
    }

    // MARK: - Layout (workspace-scoped)

    var layoutMode: LayoutMode {
        get { currentWorkspace?.layoutMode ?? .single }
        set { updateCurrentWorkspace { $0.layoutMode = newValue } }
    }

    var activeAgentIds: [UUID] {
        get { currentWorkspace?.activeAgentIds ?? [] }
        set { updateCurrentWorkspace { $0.activeAgentIds = newValue } }
    }

    var focusedPaneIndex: Int {
        get { currentWorkspace?.focusedPaneIndex ?? 0 }
        set { updateCurrentWorkspace { $0.focusedPaneIndex = newValue } }
    }

    var splitRatio: CGFloat {
        get { currentWorkspace?.splitRatio ?? 0.5 }
        set { updateCurrentWorkspace { $0.splitRatio = newValue } }
    }

    var splitRatioSecondary: CGFloat {
        get { currentWorkspace?.effectiveSplitRatioSecondary ?? 0.5 }
        set { updateCurrentWorkspace { $0.splitRatioSecondary = newValue } }
    }

    private func updateCurrentWorkspace(_ update: (inout Workspace) -> Void) {
        guard let id = currentWorkspaceId,
              var workspace = workspaces.first(where: { $0.id == id }),
              let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        update(&workspace)
        workspaces[index] = workspace
        // Note: Don't save on every layout change for performance
        // Layout is saved when switching workspaces or on explicit save
    }

    // MARK: - Workspace CRUD

    func addWorkspace(name: String, color: WorkspaceColor = .blue) -> Workspace {
        let workspace = Workspace(name: name, colorHex: color.rawValue)
        workspaces.append(workspace)
        currentWorkspaceId = workspace.id
        settings.currentWorkspaceId = workspace.id
        saveWorkspaces()
        return workspace
    }

    func removeWorkspace(_ workspace: Workspace) {
        // Close all agents in this workspace
        let agentsToRemove = workspace.agentIds.compactMap { id in agents.first { $0.id == id } }
        for agent in agentsToRemove {
            removeAgentFromAllWorkspaces(agent)
        }

        workspaces.removeAll { $0.id == workspace.id }

        // If this was the current workspace, switch to another or clear
        if currentWorkspaceId == workspace.id {
            currentWorkspaceId = workspaces.first?.id
            settings.currentWorkspaceId = currentWorkspaceId
        }

        saveWorkspaces()
    }

    func updateWorkspace(id: UUID, name: String, colorHex: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = name
        workspaces[index].colorHex = colorHex
        saveWorkspaces()
    }

    func switchToWorkspace(_ workspaceId: UUID) {
        guard workspaces.contains(where: { $0.id == workspaceId }) else { return }
        // Save current workspace layout before switching
        saveWorkspaces()
        currentWorkspaceId = workspaceId
        settings.currentWorkspaceId = workspaceId

        // Auto-select first agent if none is active
        if activeAgentIds.isEmpty, let firstAgent = currentWorkspaceAgents.first {
            layoutMode = .single
            activeAgentIds = [firstAgent.id]
        }
    }

    func switchToWorkspaceAtIndex(_ index: Int) {
        guard index >= 0, index < workspaces.count else { return }
        switchToWorkspace(workspaces[index].id)
    }

    func moveWorkspace(from source: IndexSet, to destination: Int) {
        workspaces.move(fromOffsets: source, toOffset: destination)
        saveWorkspaces()
    }

    /// Returns the "worst" status across all agents in a workspace (input > running > idle)
    func workspaceStatus(_ workspace: Workspace) -> AgentStatus? {
        let statuses = workspace.agentIds.compactMap { agentId in
            agents.first { $0.id == agentId }?.status
        }
        if statuses.contains(.input) { return .input }
        if statuses.contains(.running) { return .running }
        return nil
    }

    private func saveWorkspaces() {
        settings.saveWorkspaces(workspaces)
    }

    /// Create default "Skwad" workspace when first agent is added and no workspaces exist
    private func ensureWorkspaceExists() -> UUID {
        if let currentId = currentWorkspaceId {
            return currentId
        }

        // No workspace exists, create default "Skwad" workspace
        let workspace = Workspace.createDefault()
        workspaces = [workspace]
        currentWorkspaceId = workspace.id
        settings.currentWorkspaceId = workspace.id
        saveWorkspaces()
        return workspace.id
    }

    // MARK: - Derived state

    /// The agent in the focused pane (used for git panel, voice, keyboard shortcuts)
    var activeAgentId: UUID? {
        guard focusedPaneIndex < activeAgentIds.count else { return activeAgentIds.first }
        return activeAgentIds[focusedPaneIndex]
    }

    /// The agent currently shown in single mode / pane 0 (kept for convenience)
    var selectedAgentId: UUID? {
        activeAgentIds.first
    }

    var selectedAgent: Agent? {
        guard let id = selectedAgentId else { return nil }
        return agents.first { $0.id == id }
    }

    /// Get companions for an agent
    func companions(of agentId: UUID) -> [Agent] {
        agents.filter { $0.createdBy == agentId && $0.isCompanion }
    }

    /// Whether an agent should appear selected in the sidebar (itself or one of its companions is active)
    func isAgentActive(_ agentId: UUID) -> Bool {
        agentId == activeAgentId ||
        companions(of: agentId).contains { $0.id == activeAgentId }
    }

    /// Which pane index an agent occupies, or nil if not in any pane
    func paneIndex(for agentId: UUID) -> Int? {
        activeAgentIds.firstIndex(of: agentId)
    }

    // MARK: - Controller Management

    /// Create a controller for an agent
    func createController(for agent: Agent) -> TerminalSessionController {
        // Shell: no tracking. Hook agents (claude): .all with longer idle timeout. Others: .all.
        let tracking: ActivityTracking
        let idleTimeout: TimeInterval
        if agent.isShell {
            tracking = .none
            idleTimeout = TimingConstants.idleTimeout
        } else if TerminalCommandBuilder.usesActivityHooks(agentType: agent.agentType) {
            tracking = .all
            idleTimeout = TimingConstants.hookFallbackIdleTimeout
            // Set running so UI shows "Working" while agent boots up
            // Skip for resumed sessions — agent stays idle until user sends input
            if agent.resumeSessionId == nil, let index = agents.firstIndex(where: { $0.id == agent.id }) {
                agents[index].status = .running
            }
        } else {
            tracking = .all
            idleTimeout = TimingConstants.idleTimeout
        }
        let controller = TerminalSessionController(
            agentId: agent.id,
            folder: agent.folder,
            agentType: agent.agentType,
            shellCommand: agent.shellCommand,
            resumeSessionId: agent.resumeSessionId,
            forkSession: agent.forkSession,
            activityTracking: tracking,
            idleTimeout: idleTimeout,
            onStatusChange: { [weak self] status, source in
                self?.updateStatus(for: agent.id, status: status, source: source)
            },
            onTitleChange: { [weak self] title in
                self?.updateTitle(for: agent.id, title: title)
            }
        )

        // Restored shell agents defer their command to avoid startup congestion
        if agent.isPendingStart {
            controller.onDeferredStart = { [weak self] ctrl in
                self?.enqueueShellStart(ctrl, isCompanion: agent.isCompanion)
            }
        }

        controllers[agent.id] = controller
        return controller
    }

    /// Get existing controller for an agent
    func getController(for agentId: UUID) -> TerminalSessionController? {
        controllers[agentId]
    }

    /// Remove controller for an agent
    func removeController(for agentId: UUID) {
        controllers[agentId]?.dispose()
        controllers.removeValue(forKey: agentId)
    }

    /// Terminate all agents - called on app quit
    func terminateAll() {
        print("[skwad] Terminating all agents")
        for controller in controllers.values {
            controller.dispose()
        }
        controllers.removeAll()
        terminals.removeAll()
        print("[skwad] All agents terminated")
    }

    // MARK: - Deferred Shell Startup

    /// Pending shell controllers waiting to be started, ordered by priority
    /// (main shells first, companion shells second)
    private var shellStartQueue: [TerminalSessionController] = []
    private var shellStartTask: Task<Void, Never>?

    /// Enqueue a shell agent's command for staggered execution
    private func enqueueShellStart(_ controller: TerminalSessionController, isCompanion: Bool) {
        // Show a waiting banner in the terminal
        // Prefix with space to prevent shell history pollution
        let banner = [
            " clear",
            "printf '\\n'",
            "printf '          \\e[2m╭─────────────────────────────╮\\e[0m\\n'",
            "printf '          \\e[2m│                             │\\e[0m\\n'",
            "printf '          \\e[2m│     \\e[0m\\e[1;97m⏳ Starting soon...\\e[0m\\e[2m     │\\e[0m\\n'",
            "printf '          \\e[2m│                             │\\e[0m\\n'",
            "printf '          \\e[2m╰─────────────────────────────╯\\e[0m\\n'",
            "printf '\\n'",
            "printf '\\n'",
            "printf '\\n'"
        ].joined(separator: " && ")
        controller.sendCommand(banner)

        if isCompanion {
            shellStartQueue.append(controller)
        } else {
            // Main shells go before companions
            let firstCompanionIndex = shellStartQueue.firstIndex { ctrl in
                agents.first { $0.id == ctrl.agentId }?.isCompanion == true
            } ?? shellStartQueue.endIndex
            shellStartQueue.insert(controller, at: firstCompanionIndex)
        }
        drainShellStartQueue()
    }

    /// Process the queue: wait for initial delay, then send one command at a time with stagger
    private func drainShellStartQueue() {
        guard shellStartTask == nil, !shellStartQueue.isEmpty else { return }
        shellStartTask = Task { [weak self] in
            // Initial delay to let non-shell agents settle
            try? await Task.sleep(for: .seconds(TimingConstants.shellStartInitialDelay))

            while let self, !self.shellStartQueue.isEmpty {
                let controller = self.shellStartQueue.removeFirst()

                // Clear pending state
                if let index = self.agents.firstIndex(where: { $0.id == controller.agentId }) {
                    self.agents[index].isPendingStart = false
                }

                let command = controller.buildDeferredCommand()
                if !command.isEmpty {
                    controller.sendCommand(command)
                }
                try? await Task.sleep(for: .seconds(TimingConstants.shellStartStaggerDelay))
            }
            self?.shellStartTask = nil
        }
    }

    // MARK: - Terminal Management (for forceRefresh on resize)

    func registerTerminal(_ terminal: GhosttyTerminalView, for agentId: UUID) {
        terminals[agentId] = WeakTerminalRef(terminal)
    }

    func unregisterTerminal(for agentId: UUID) {
        terminals.removeValue(forKey: agentId)
    }

    func getTerminal(for agentId: UUID) -> GhosttyTerminalView? {
        terminals[agentId]?.terminal
    }

    // MARK: - Text Injection (delegates to controller)

    /// Send text to an agent's terminal WITHOUT return
    func sendText(_ text: String, for agentId: UUID) {
        controllers[agentId]?.sendText(text)
    }

    /// Send return key to an agent's terminal
    func sendReturn(for agentId: UUID) {
        controllers[agentId]?.sendReturn()
    }

    /// Inject text into an agent's terminal followed by return
    func injectText(_ text: String, for agentId: UUID) {
        controllers[agentId]?.injectText(text)
    }

    /// Notify terminal to resize (e.g., when git panel toggles)
    func notifyTerminalResize(for agentId: UUID) {
        controllers[agentId]?.notifyResize()
    }

    // MARK: - Registration State

    /// Inject the registration prompt into an agent's terminal
    func registerAgent(_ agent: Agent) {
        let text = "You are part of a team of agents called a skwad. Register within the skwad with your agent ID: \(agent.id.uuidString). A skwad is made of  high-performing agents who collaborate to achieve complex goals so engage with them: ask for help and in return help them succeed."
        injectText(text, for: agent.id)
    }

    func setRegistered(for agentId: UUID, registered: Bool) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].isRegistered = registered
        }
    }

    func isRegistered(agentId: UUID) -> Bool {
        agents.first { $0.id == agentId }?.isRegistered ?? false
    }

    func setSessionId(for agentId: UUID, sessionId: String) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].sessionId = sessionId
        }
    }

    func updateMetadata(for agentId: UUID, metadata: [String: String]) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].metadata.merge(metadata) { _, new in new }
        }
    }

    // MARK: - Agent CRUD

    @discardableResult
    func addAgent(
        folder: String,
        name: String? = nil,
        avatar: String? = nil,
        agentType: String = "claude",
        createdBy: UUID? = nil,
        isCompanion: Bool = false,
        insertAfterId: UUID? = nil,
        shellCommand: String? = nil,
        resumeSessionId: String? = nil,
        forkSession: Bool = false
    ) -> UUID? {
        var agent = Agent(folder: folder, avatar: avatar, agentType: agentType, createdBy: createdBy, isCompanion: isCompanion, shellCommand: shellCommand)
        agent.resumeSessionId = resumeSessionId
        agent.forkSession = forkSession
        if let name = name {
            agent.name = name
        }

        // Add to master agent list
        if let insertAfterId = insertAfterId,
           let index = agents.firstIndex(where: { $0.id == insertAfterId }) {
            let insertIndex = agents.index(after: index)
            agents.insert(agent, at: insertIndex)
        } else {
            agents.append(agent)
        }

        // Ensure we have a workspace (creates "Skwad" if needed)
        let workspaceId = ensureWorkspaceExists()

        // Add agent to current workspace
        if let index = workspaces.firstIndex(where: { $0.id == workspaceId }) {
            if let insertAfterId = insertAfterId,
               let insertAfterIndex = workspaces[index].agentIds.firstIndex(of: insertAfterId) {
                workspaces[index].agentIds.insert(agent.id, at: insertAfterIndex + 1)
            } else {
                workspaces[index].agentIds.append(agent.id)
            }

            // Set as active if no active agents
            if workspaces[index].activeAgentIds.isEmpty {
                workspaces[index].activeAgentIds = [agent.id]
            }
        }

        saveAgents()
        saveWorkspaces()

        // Add to recent agents
        settings.addRecentAgent(agent)

        return agent.id
    }

    func removeAgent(_ agent: Agent) {
        // Close companions first (if this agent owns any)
        let companions = companions(of: agent.id)
        for companion in companions {
            removeAgent(companion)
        }

        // Unregister from MCP if registered
        if agent.isRegistered {
            Task {
                await MCPService.shared.unregisterAgent(agentId: agent.id.uuidString)
            }
        }

        removeController(for: agent.id)
        unregisterTerminal(for: agent.id)

        // Check if agent was in a pane BEFORE removing from workspace
        let wasInActivePane = activeAgentIds.contains(agent.id)

        // Remove from current workspace
        removeAgentFromCurrentWorkspace(agent.id)

        // Remove from master list
        agents.removeAll { $0.id == agent.id }

        // Get workspace agents after removal for selection logic
        let workspaceAgents = currentWorkspaceAgents

        if wasInActivePane {
            if layoutMode == .gridFourPane || layoutMode == .threePane {
                activeAgentIds.removeAll { $0 == agent.id }
                if activeAgentIds.count < 2 {
                    exitSplit(selecting: activeAgentIds.first ?? workspaceAgents.first?.id)
                } else {
                    // Downgrade layout to match remaining pane count
                    if activeAgentIds.count == 3 {
                        layoutMode = .threePane
                    } else if activeAgentIds.count == 2 {
                        layoutMode = .splitVertical
                    }
                    if focusedPaneIndex >= activeAgentIds.count {
                        focusedPaneIndex = activeAgentIds.count - 1
                    }
                }
            } else {
                // For other split modes, collapse to single with surviving pane agent
                let surviving = activeAgentIds.first(where: { id in id != agent.id && workspaceAgents.contains(where: { $0.id == id }) })
                exitSplit(selecting: surviving ?? workspaceAgents.first?.id)
            }
        } else if layoutMode == .single && (activeAgentIds.isEmpty || !workspaceAgents.contains(where: { $0.id == activeAgentIds[0] })) {
            // Single mode, selected agent gone → pick first
            activeAgentIds = workspaceAgents.first.map { [$0.id] } ?? []
        }

        saveAgents()
        saveWorkspaces()
    }

    /// Remove agent from current workspace only (agent remains in master list)
    private func removeAgentFromCurrentWorkspace(_ agentId: UUID) {
        guard let workspaceId = currentWorkspaceId,
              let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }
        workspaces[index].agentIds.removeAll { $0 == agentId }
        workspaces[index].activeAgentIds.removeAll { $0 == agentId }
    }

    /// Remove agent from all workspaces and master list (used when closing a workspace)
    private func removeAgentFromAllWorkspaces(_ agent: Agent) {
        // Unregister from MCP if registered
        if agent.isRegistered {
            Task {
                await MCPService.shared.unregisterAgent(agentId: agent.id.uuidString)
            }
        }

        removeController(for: agent.id)
        unregisterTerminal(for: agent.id)

        // Remove from all workspaces
        for i in workspaces.indices {
            workspaces[i].agentIds.removeAll { $0 == agent.id }
            workspaces[i].activeAgentIds.removeAll { $0 == agent.id }
        }

        // Remove from master list
        agents.removeAll { $0.id == agent.id }
        saveAgents()
    }

    @discardableResult
    func createDuplicateAgent(_ agent: Agent, nameSuffix: String = " (copy)") -> Agent {
        var newAgent = Agent(folder: agent.folder, avatar: agent.avatar, agentType: agent.agentType)
        newAgent.name = agent.name + nameSuffix

        // Add to master list
        agents.append(newAgent)

        // Add to current workspace
        if let workspaceId = currentWorkspaceId,
           let index = workspaces.firstIndex(where: { $0.id == workspaceId }) {
            workspaces[index].agentIds.append(newAgent.id)
        }

        saveAgents()
        saveWorkspaces()
        return newAgent
    }

    func duplicateAgent(_ agent: Agent) {
        _ = createDuplicateAgent(agent)
    }

    func createShellCompanion(for agent: Agent) {
        guard !agent.isCompanion else { return }
        guard let newId = addAgent(
            folder: agent.folder,
            name: "Shell",
            agentType: "shell",
            createdBy: agent.id,
            isCompanion: true,
            insertAfterId: agent.id
        ) else { return }
        enterSplitWithNewAgent(newAgentId: newId, creatorId: agent.id)
    }

    /// Duplicate companions of sourceAgent onto newAgent, optionally at a new folder
    func duplicateCompanions(from sourceAgentId: UUID, to newAgentId: UUID, newFolder: String?) {
        for companion in companions(of: sourceAgentId) {
            let folder = (newFolder != nil && companion.folder == agents.first(where: { $0.id == sourceAgentId })?.folder)
                ? newFolder! : companion.folder
            addAgent(
                folder: folder,
                name: companion.name,
                avatar: companion.avatar,
                agentType: companion.agentType,
                createdBy: newAgentId,
                isCompanion: true,
                insertAfterId: newAgentId,
                shellCommand: companion.shellCommand
            )
        }
    }

    func resumeSession(_ agent: Agent, sessionId: String) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index].resumeSessionId = sessionId
        agents[index].forkSession = false
        agents[index].sessionId = sessionId
        startAgent(agents[index])
    }

    func restartAgent(_ agent: Agent) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        agents[index].sessionId = nil
        agents[index].resumeSessionId = nil
        agents[index].forkSession = false
        startAgent(agents[index])
    }

    /// Tear down existing terminal and trigger recreation via restartToken
    private func startAgent(_ agent: Agent) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        removeController(for: agent.id)
        unregisterTerminal(for: agent.id)
        agents[index].restartToken = UUID()
        agents[index].status = .idle
        agents[index].isRegistered = false
        agents[index].terminalTitle = ""
    }

    func updateAgent(id: UUID, name: String, avatar: String, folder: String? = nil, relocateCompanions: Bool = false) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        let oldFolder = agents[index].folder
        agents[index].name = name
        agents[index].avatar = avatar

        if let folder = folder, folder != oldFolder {
            agents[index].folder = folder
            // Restart the agent itself since folder changed
            restartAgent(agents[index])

            if relocateCompanions {
                for companion in companions(of: id) {
                    guard companion.folder == oldFolder else { continue }
                    if let ci = agents.firstIndex(where: { $0.id == companion.id }) {
                        agents[ci].folder = folder
                        restartAgent(agents[ci])
                    }
                }
            }
        }

        saveAgents()
    }

    func moveAgent(from source: IndexSet, to destination: Int) {
        // Move within current workspace's agent list
        guard let workspaceId = currentWorkspaceId,
              let index = workspaces.firstIndex(where: { $0.id == workspaceId }) else { return }
        workspaces[index].agentIds.move(fromOffsets: source, toOffset: destination)
        saveWorkspaces()
    }

    func moveAgentToWorkspace(_ agent: Agent, to targetWorkspaceId: UUID) {
        guard let sourceWorkspaceId = currentWorkspaceId,
              sourceWorkspaceId != targetWorkspaceId,
              let sourceIndex = workspaces.firstIndex(where: { $0.id == sourceWorkspaceId }),
              let targetIndex = workspaces.firstIndex(where: { $0.id == targetWorkspaceId }) else { return }

        // Remove from source workspace
        workspaces[sourceIndex].agentIds.removeAll { $0 == agent.id }
        workspaces[sourceIndex].activeAgentIds.removeAll { $0 == agent.id }

        // Add to target workspace
        workspaces[targetIndex].agentIds.append(agent.id)

        // Update selection in source workspace if needed
        let sourceAgents = workspaces[sourceIndex].agentIds
        if workspaces[sourceIndex].activeAgentIds.isEmpty && !sourceAgents.isEmpty {
            workspaces[sourceIndex].activeAgentIds = [sourceAgents[0]]
        }

        saveWorkspaces()
    }

    private func saveAgents() {
        settings.saveAgents(agents)
    }

    func updateStatus(for agentId: UUID, status: AgentStatus, source: ActivitySource = .terminal) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            guard agents[index].status != status else { return }
            agents[index].status = status
            if status == .input {
                controllers[agentId]?.status = .input
            }
            if status == .running && source == .hook {
                controllers[agentId]?.cancelInputProtection()
            }
            if status == .idle && !agents[index].isShell {
                refreshGitStats(for: agentId)
            }
        }
    }

    func updateTitle(for agentId: UUID, title: String) {
        // Strip leading spinner/status indicators (⠂, ⠐, ✳, ●, etc.)
        var cleanTitle = title
        while let first = cleanTitle.unicodeScalars.first,
              !first.isASCII || first == " " {
            cleanTitle = String(cleanTitle.dropFirst())
        }
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespaces)

        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            guard agents[index].terminalTitle != cleanTitle else { return }
            agents[index].terminalTitle = cleanTitle
        }
    }

    // MARK: - Layout / Split Pane

    /// Apply the correct layout for an agent and its companions
    func applyCompanionLayout(for agentId: UUID) {
        let companions = companions(of: agentId)
        if companions.isEmpty {
            activeAgentIds = [agentId]
            layoutMode = .single
        } else {
            let companionIds = companions.prefix(3).map { $0.id }
            activeAgentIds = [agentId] + companionIds
            switch companionIds.count {
            case 1: layoutMode = .splitVertical
            case 2: layoutMode = .threePane
            default: layoutMode = .gridFourPane
            }
        }
        focusedPaneIndex = 0
    }

    func enterSplit(_ mode: LayoutMode) {
        let workspaceAgents = currentWorkspaceAgents
        guard workspaceAgents.count >= 2 else { return }
        guard let currentId = activeAgentIds.first,
              let currentIndex = workspaceAgents.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % workspaceAgents.count
        activeAgentIds = [currentId, workspaceAgents[nextIndex].id]
        layoutMode = mode
        focusedPaneIndex = 0
    }

    private func exitSplit(selecting id: UUID? = nil) {
        let workspaceAgents = currentWorkspaceAgents
        let keepId = id ?? (focusedPaneIndex < activeAgentIds.count ? activeAgentIds[focusedPaneIndex] : nil)
        activeAgentIds = keepId.map { [$0] } ?? (workspaceAgents.first.map { [$0.id] } ?? [])
        layoutMode = .single
        focusedPaneIndex = 0
    }

    /// Enters split view showing the creator agent and a newly created agent
    /// Called when an agent creates a companion agent
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
            // Dual → Three-pane: keep existing 2 agents, add new agent as pane 2
            var newActiveIds = activeAgentIds
            newActiveIds.append(newAgentId)
            activeAgentIds = Array(newActiveIds.prefix(3))
            layoutMode = .threePane
            // Focus the new agent's pane
            if let newPane = activeAgentIds.firstIndex(of: newAgentId) {
                focusedPaneIndex = newPane
            }

        case .threePane:
            // Three-pane → Four-pane grid: add new agent as pane 3
            var newActiveIds = activeAgentIds
            newActiveIds.append(newAgentId)
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

            for pane in replacementOrder where pane < activeAgentIds.count {
                if pane != creatorPane {
                    activeAgentIds[pane] = newAgentId
                    replacedPane = pane
                    break
                }
            }

            // Edge case: creator is in all considered panes (shouldn't happen, but fallback)
            if replacedPane == nil, activeAgentIds.count > 3 {
                activeAgentIds[3] = newAgentId
                replacedPane = 3
            }

            focusedPaneIndex = replacedPane ?? 3
        }
    }

    func focusPane(_ index: Int) {
        guard layoutMode != .single, index < activeAgentIds.count else { return }
        focusedPaneIndex = index
    }

    func selectAgent(_ agentId: UUID, skipCompanionLayout: Bool = false) {
        // Rule 1: Agent has companions and pane 0 is focused → companion layout
        if !skipCompanionLayout && !companions(of: agentId).isEmpty && focusedPaneIndex == 0 {
            applyCompanionLayout(for: agentId)
            return
        }

        // Rule 2: Currently selected agent (pane 0) has companions → collapse to single
        if let currentId = activeAgentIds.first, !companions(of: currentId).isEmpty {
            activeAgentIds = [agentId]
            layoutMode = .single
            focusedPaneIndex = 0
            return
        }

        // Rule 3: Agent already in a pane → just focus it
        if let pane = activeAgentIds.firstIndex(of: agentId) {
            focusedPaneIndex = pane
            return
        }

        // Rule 4: Place in focused pane
        if layoutMode == .single {
            activeAgentIds = [agentId]
        } else {
            activeAgentIds[focusedPaneIndex] = agentId
        }
    }

    // MARK: - Agent Navigation

    func selectNextAgent() {
        // Cycle through sidebar items (non-companion agents)
        let navigableAgents = currentWorkspaceAgents.filter { !$0.isCompanion }
        guard !navigableAgents.isEmpty else { return }
        guard let currentIndex = navigableAgents.firstIndex(where: { $0.id == activeAgentId }) else {
            selectAgent(navigableAgents[0].id)
            return
        }
        let nextIndex = (currentIndex + 1) % navigableAgents.count
        selectAgent(navigableAgents[nextIndex].id)
    }

    func selectPreviousAgent() {
        // Cycle through sidebar items (non-companion agents)
        let navigableAgents = currentWorkspaceAgents.filter { !$0.isCompanion }
        guard !navigableAgents.isEmpty else { return }
        guard let currentIndex = navigableAgents.firstIndex(where: { $0.id == activeAgentId }) else {
            if let lastAgent = navigableAgents.last {
                selectAgent(lastAgent.id)
            }
            return
        }
        let previousIndex = (currentIndex - 1 + navigableAgents.count) % navigableAgents.count
        selectAgent(navigableAgents[previousIndex].id)
    }

    func selectAgentAtIndex(_ index: Int) {
        let navigableAgents = currentWorkspaceAgents.filter { !$0.isCompanion }
        guard index >= 0 && index < navigableAgents.count else { return }
        let agentId = navigableAgents[index].id

        if layoutMode != .single {
            // If agent is already in a pane, focus that pane
            if let pane = paneIndex(for: agentId) {
                focusedPaneIndex = pane
            } else {
                selectAgent(agentId)
            }
        } else {
            activeAgentIds = [agentId]
        }
    }

    // MARK: - Git Stats

    func refreshGitStats(forFolder folder: String) {
        guard let agent = agents.first(where: { $0.folder == folder }) else { return }
        refreshGitStats(for: agent.id)
    }

    private func refreshGitStats(for agentId: UUID) {
        guard let agent = agents.first(where: { $0.id == agentId }) else { return }

        guard GitWorktreeManager.shared.isGitRepo(agent.folder) else {
            if let index = agents.firstIndex(where: { $0.id == agentId }) {
                agents[index].gitStats = nil
            }
            return
        }

        let folder = agent.folder
        gitStatsQueue.async { [weak self] in
            let repo = GitRepository(path: folder)
            let stats = repo.combinedDiffStats()

            DispatchQueue.main.async {
                guard let self,
                      let index = self.agents.firstIndex(where: { $0.id == agentId }) else { return }
                self.agents[index].gitStats = stats
            }
        }
    }

    // MARK: - Markdown Panel

    /// Show the markdown panel for a specific file
    func showMarkdownPanel(filePath: String, maximized: Bool = false, forAgent agentId: UUID) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].markdownFilePath = filePath
            agents[index].markdownMaximized = maximized
            // Add to history (remove if already present to move to front)
            agents[index].markdownFileHistory.removeAll { $0 == filePath }
            agents[index].markdownFileHistory.insert(filePath, at: 0)
        }
    }

    /// Close the markdown panel for an agent
    func closeMarkdownPanel(for agentId: UUID) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].markdownFilePath = nil
        }
    }
}
