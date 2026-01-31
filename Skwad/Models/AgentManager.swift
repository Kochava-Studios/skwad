import Foundation
import SwiftUI

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
    @Published var selectedAgentId: UUID?

    private let settings = AppSettings.shared

    // Terminal references for each agent (keyed by agent ID)
    // Uses weak references to avoid retain cycles with SwiftUI view lifecycle
    private var terminals: [UUID: WeakTerminalRef] = [:]

    // Controllers for each agent (keyed by agent ID)
    private var controllers: [UUID: TerminalSessionController] = [:]

    init() {
        if settings.restoreLayoutOnLaunch {
            agents = settings.loadSavedAgents()
            selectedAgentId = agents.first?.id
        }
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

    var selectedAgent: Agent? {
        guard let id = selectedAgentId else { return nil }
        return agents.first { $0.id == id }
    }

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
        selectedAgentId = agent.id
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
        if selectedAgentId == agent.id {
            selectedAgentId = agents.first?.id
        }
        saveAgents()
    }

    @discardableResult
    func createDuplicateAgent(_ agent: Agent, nameSuffix: String = " (copy)") -> Agent {
        var newAgent = Agent(folder: agent.folder, avatar: agent.avatar, agentType: agent.agentType)
        newAgent.name = agent.name + nameSuffix
        agents.append(newAgent)
        selectedAgentId = newAgent.id
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

    func select(_ agent: Agent) {
        selectedAgentId = agent.id
    }

    func selectNextAgent() {
        guard !agents.isEmpty else { return }
        guard let currentId = selectedAgentId,
              let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else {
            selectedAgentId = agents.first?.id
            return
        }
        let nextIndex = (currentIndex + 1) % agents.count
        selectedAgentId = agents[nextIndex].id
    }

    func selectPreviousAgent() {
        guard !agents.isEmpty else { return }
        guard let currentId = selectedAgentId,
              let currentIndex = agents.firstIndex(where: { $0.id == currentId }) else {
            selectedAgentId = agents.last?.id
            return
        }
        let previousIndex = (currentIndex - 1 + agents.count) % agents.count
        selectedAgentId = agents[previousIndex].id
    }

    func selectAgentAtIndex(_ index: Int) {
        guard index >= 0 && index < agents.count else { return }
        selectedAgentId = agents[index].id
    }

    func refreshGitStats(forFolder folder: String) {
        guard let agent = agents.first(where: { $0.folder == folder }) else { return }
        refreshGitStats(for: agent.id)
    }

    // MARK: - Git Stats

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
