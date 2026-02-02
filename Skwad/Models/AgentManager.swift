import Foundation
import SwiftUI

enum LayoutMode {
    case single
    case splitVertical   // left | right
    case splitHorizontal // top / bottom
    case gridFourPane    // 4-pane grid (up to 4 agents)
}

// Weak wrapper for terminal references to avoid retain cycles
private class WeakTerminalRef {
    weak var terminal: GhosttyTerminalView?
    init(_ terminal: GhosttyTerminalView) {
        self.terminal = terminal
    }
}

@MainActor
class AgentManager: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var layoutMode: LayoutMode = .single
    @Published var activeAgentIds: [UUID] = []   // count matches pane count: 1 for single, 2 for split
    @Published var focusedPaneIndex: Int = 0
    @Published var splitRatio: CGFloat = 0.5

    private let settings = AppSettings.shared

    // Terminal references for each agent (keyed by agent ID)
    // Uses weak references to avoid retain cycles with SwiftUI view lifecycle
    private var terminals: [UUID: WeakTerminalRef] = [:]

    // Controllers for each agent (keyed by agent ID)
    private var controllers: [UUID: TerminalSessionController] = [:]

    init() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        if settings.restoreLayoutOnLaunch {
            agents = settings.loadSavedAgents()
            if let first = agents.first {
                activeAgentIds = [first.id]
            }
        }
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

    /// Which pane index an agent occupies, or nil if not in any pane
    func paneIndex(for agentId: UUID) -> Int? {
        activeAgentIds.firstIndex(of: agentId)
    }

    // MARK: - Controller Management

    /// Create a controller for an agent
    func createController(for agent: Agent) -> TerminalSessionController {
        let controller = TerminalSessionController(
            agentId: agent.id,
            folder: agent.folder,
            agentType: agent.agentType,
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

    func setRegistered(for agentId: UUID, registered: Bool) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].isRegistered = registered
        }
    }

    func isRegistered(agentId: UUID) -> Bool {
        agents.first { $0.id == agentId }?.isRegistered ?? false
    }

    // MARK: - Agent CRUD

    func addAgent(
        folder: String,
        name: String? = nil,
        avatar: String? = nil,
        agentType: String = "claude",
        insertAfterId: UUID? = nil
    ) {
        var agent = Agent(folder: folder, avatar: avatar, agentType: agentType)
        if let name = name {
            agent.name = name
        }

        if let insertAfterId = insertAfterId,
           let index = agents.firstIndex(where: { $0.id == insertAfterId }) {
            let insertIndex = agents.index(after: index)
            agents.insert(agent, at: insertIndex)
        } else {
            agents.append(agent)
        }
        if activeAgentIds.isEmpty {
            activeAgentIds = [agent.id]
        }
        saveAgents()

        // Add to recent agents
        settings.addRecentAgent(agent)
    }

    func removeAgent(_ agent: Agent) {
        // Unregister from MCP if registered
        if agent.isRegistered {
            Task {
                await MCPService.shared.unregisterAgent(agentId: agent.id.uuidString)
            }
        }

        removeController(for: agent.id)
        unregisterTerminal(for: agent.id)
        agents.removeAll { $0.id == agent.id }

        if activeAgentIds.contains(agent.id) {
            // For 4-pane grid, just remove the agent from activeAgentIds but stay in grid mode
            if layoutMode == .gridFourPane {
                activeAgentIds.removeAll { $0 == agent.id }
                // If we have less than 2 agents remaining in the grid, exit to single
                if activeAgentIds.count < 2 {
                    exitSplit(selecting: activeAgentIds.first ?? agents.first?.id)
                } else if focusedPaneIndex >= activeAgentIds.count {
                    focusedPaneIndex = activeAgentIds.count - 1
                }
            } else {
                // For other split modes, collapse to single with surviving pane agent
                let surviving = activeAgentIds.first(where: { id in id != agent.id && agents.contains(where: { $0.id == id }) })
                exitSplit(selecting: surviving ?? agents.first?.id)
            }
        } else if layoutMode == .single && (activeAgentIds.isEmpty || !agents.contains(where: { $0.id == activeAgentIds[0] })) {
            // Single mode, selected agent gone → pick first
            activeAgentIds = agents.first.map { [$0.id] } ?? []
        }

        saveAgents()
    }

    @discardableResult
    func createDuplicateAgent(_ agent: Agent, nameSuffix: String = " (copy)") -> Agent {
        var newAgent = Agent(folder: agent.folder, avatar: agent.avatar, agentType: agent.agentType)
        newAgent.name = agent.name + nameSuffix
        agents.append(newAgent)
        saveAgents()
        return newAgent
    }

    func duplicateAgent(_ agent: Agent) {
        _ = createDuplicateAgent(agent)
    }

    func restartAgent(_ agent: Agent) {
        // Keep same ID but regenerate restart token to force terminal recreation
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        removeController(for: agent.id)
        unregisterTerminal(for: agent.id)

        // Update agent with new restart token (keeps same ID for MCP registration)
        agents[index].restartToken = UUID()
        agents[index].status = .idle
        agents[index].isRegistered = false
        agents[index].terminalTitle = ""
    }

    func updateAgent(id: UUID, name: String, avatar: String) {
        if let index = agents.firstIndex(where: { $0.id == id }) {
            agents[index].name = name
            agents[index].avatar = avatar
            saveAgents()
        }
    }

    func moveAgent(from source: IndexSet, to destination: Int) {
        agents.move(fromOffsets: source, toOffset: destination)
        saveAgents()
    }

    private func saveAgents() {
        settings.saveAgents(agents)
    }

    func updateStatus(for agentId: UUID, status: AgentStatus) {
        Task { @MainActor in
            if let index = agents.firstIndex(where: { $0.id == agentId }) {
                agents[index].status = status
                if status == .idle {
                    refreshGitStats(for: agentId)
                }
            }
        }
    }

    func updateTitle(for agentId: UUID, title: String) {
        if let index = agents.firstIndex(where: { $0.id == agentId }) {
            agents[index].terminalTitle = title
        }
    }

    // MARK: - Layout / Split Pane

    func enterSplit(_ mode: LayoutMode) {
        guard agents.count >= 2 else { return }
        guard let currentId = activeAgentIds.first,
              let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % agents.count
        activeAgentIds = [currentId, agents[nextIndex].id]
        layoutMode = mode
        focusedPaneIndex = 0
    }

    private func exitSplit(selecting id: UUID? = nil) {
        let keepId = id ?? (focusedPaneIndex < activeAgentIds.count ? activeAgentIds[focusedPaneIndex] : nil)
        activeAgentIds = keepId.map { [$0] } ?? (agents.first.map { [$0.id] } ?? [])
        layoutMode = .single
        focusedPaneIndex = 0
    }

    func focusPane(_ index: Int) {
        guard layoutMode != .single, index < activeAgentIds.count else { return }
        focusedPaneIndex = index
    }

    func assignAgentToFocusedPane(_ agentId: UUID) {
        if layoutMode == .single {
            activeAgentIds = [agentId]
            return
        }

        // If agent is already in a pane, just focus that pane
        if let paneIndex = activeAgentIds.firstIndex(of: agentId) {
            focusedPaneIndex = paneIndex
        } else {
            // Agent not in any pane → assign to focused pane
            activeAgentIds[focusedPaneIndex] = agentId
        }
    }

    // MARK: - Agent Navigation

    func select(_ agent: Agent) {
        assignAgentToFocusedPane(agent.id)
    }

    func selectNextAgent() {
        guard !agents.isEmpty else { return }
        let currentId = activeAgentId
        guard let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else {
            activeAgentIds = [agents[0].id]
            return
        }

        if layoutMode != .single {
            // Cycle into focused pane, skip agents in other panes
            var next = (currentIndex + 1) % agents.count
            while activeAgentIds.contains(agents[next].id) && agents[next].id != currentId {
                next = (next + 1) % agents.count
            }
            activeAgentIds[focusedPaneIndex] = agents[next].id
        } else {
            let nextIndex = (currentIndex + 1) % agents.count
            activeAgentIds = [agents[nextIndex].id]
        }
    }

    func selectPreviousAgent() {
        guard !agents.isEmpty else { return }
        let currentId = activeAgentId
        guard let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else {
            if let lastAgent = agents.last {
                activeAgentIds = [lastAgent.id]
            }
            return
        }

        if layoutMode != .single {
            var prev = (currentIndex - 1 + agents.count) % agents.count
            while activeAgentIds.contains(agents[prev].id) && agents[prev].id != currentId {
                prev = (prev - 1 + agents.count) % agents.count
            }
            activeAgentIds[focusedPaneIndex] = agents[prev].id
        } else {
            let previousIndex = (currentIndex - 1 + agents.count) % agents.count
            activeAgentIds = [agents[previousIndex].id]
        }
    }

    func selectAgentAtIndex(_ index: Int) {
        guard index >= 0 && index < agents.count else { return }
        let agentId = agents[index].id

        if layoutMode != .single {
            // If agent is already in a pane, focus that pane
            if let pane = paneIndex(for: agentId) {
                focusedPaneIndex = pane
            } else {
                assignAgentToFocusedPane(agentId)
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let repo = GitRepository(path: folder)
            let unstaged = repo.diffStats()
            let staged = repo.diffStats(staged: true, includeUntracked: false)

            let stats = GitLineStats(
                insertions: unstaged.insertions + staged.insertions,
                deletions: unstaged.deletions + staged.deletions,
                files: unstaged.files + staged.files
            )

            DispatchQueue.main.async {
                guard let self = self,
                      let index = self.agents.firstIndex(where: { $0.id == agentId }) else { return }
                self.agents[index].gitStats = stats
            }
        }
    }
}
