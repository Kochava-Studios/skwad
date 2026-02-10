import Foundation
import Logging

// MARK: - MCP Service Protocol

protocol MCPServiceProtocol {
    func listAgents(callerAgentId: String) async -> [AgentInfo]
    func registerAgent(agentId: String) async -> Bool
    func unregisterAgent(agentId: String) async -> Bool
    func sendMessage(from: String, to: String, content: String) async -> String?
    func checkMessages(for agentId: String, markAsRead: Bool) async -> [MCPMessage]
    func broadcastMessage(from: String, content: String) async -> Int
    func hasUnreadMessages(for agentId: String) async -> Bool
}

// MARK: - Agent Data Provider Protocol
// Allows MCPService to query agent data without holding a reference to AgentManager

protocol AgentDataProvider: Sendable {
    func getAgents() async -> [Agent]
    func getAgent(id: UUID) async -> Agent?
    func getAgentsInSameWorkspace(as agentId: UUID) async -> [Agent]
    func setRegistered(for agentId: UUID, registered: Bool) async
    func injectText(_ text: String, for agentId: UUID) async
    func addAgent(folder: String, name: String, avatar: String?, agentType: String, createdBy: UUID?, companion: Bool, shellCommand: String?) async -> UUID?
    func removeAgent(id: UUID) async -> Bool
    func showMarkdownPanel(filePath: String, agentId: UUID) async -> Bool
}

// MARK: - MCP Service

actor MCPService: MCPServiceProtocol {
    static let shared = MCPService()

    private let logger = Logger(label: "com.skwad.mcp")
    private let sessionManager = MCPSessionManager()
    private let messageStore = MCPMessageStore()

    // Agent data provider - queried through async boundaries
    private var agentDataProvider: AgentDataProvider?

    private init() {}

    // MARK: - Agent Manager Integration

    func setAgentDataProvider(_ provider: AgentDataProvider) {
        agentDataProvider = provider
    }

    // Legacy method for compatibility during transition
    func setAgentManager(_ manager: AgentManager) {
        // Create a wrapper that safely queries the MainActor-isolated AgentManager
        let wrapper = AgentManagerWrapper(manager: manager)
        agentDataProvider = wrapper
    }

    // MARK: - Agent Operations

    func listAgents(callerAgentId: String) async -> [AgentInfo] {
        guard let callerUUID = UUID(uuidString: callerAgentId) else {
            logger.warning("[skwad] Invalid caller agent ID: \(callerAgentId)")
            return []
        }

        guard let provider = agentDataProvider else {
            logger.warning("[skwad] AgentDataProvider not available")
            return []
        }

        // Only return agents in the same workspace as the caller
        let allAgents = await provider.getAgentsInSameWorkspace(as: callerUUID)
        let agents = allAgents.filter { agent in
            // Never include shell agents
            if agent.isShell { return false }
            // Only include companion agents if the caller is their owner
            if agent.isCompanion { return agent.createdBy == callerUUID }
            return true
        }
        return agents.map { agent in
            AgentInfo(
                id: agent.id.uuidString,
                name: agent.name,
                folder: agent.folder,
                status: agent.status.rawValue,
                isRegistered: agent.isRegistered
            )
        }
    }

    func registerAgent(agentId: String) async -> Bool {
        logger.info("[skwad] Register agent called: \(agentId)")
        
        guard let uuid = UUID(uuidString: agentId) else {
            logger.error("[skwad] Invalid agent ID format: \(agentId)")
            return false
        }

        guard let provider = agentDataProvider else {
            logger.error("[skwad] AgentDataProvider not available")
            return false
        }

        // Check if agent exists
        let agents = await provider.getAgents()
        guard agents.contains(where: { $0.id == uuid }) else {
            logger.error("[skwad] Agent not found: \(agentId)")
            return false
        }

        // Mark agent as registered
        await provider.setRegistered(for: uuid, registered: true)

        // Create MCP session for this agent
        _ = await sessionManager.createSession(for: uuid)

        logger.info("[skwad][\(String(uuid.uuidString.prefix(8)).lowercased())] Agent registered")
        return true
    }
    
    func unregisterAgent(agentId: String) async -> Bool {
        logger.info("[skwad] Unregister agent called: \(agentId)")
        
        guard let uuid = UUID(uuidString: agentId) else {
            logger.error("[skwad] Invalid agent ID format: \(agentId)")
            return false
        }

        guard let provider = agentDataProvider else {
            logger.error("[skwad] AgentDataProvider not available")
            return false
        }

        // Mark agent as unregistered
        await provider.setRegistered(for: uuid, registered: false)

        // Remove MCP session for this agent
        await sessionManager.removeSession(for: uuid)

        logger.info("[skwad][\(String(uuid.uuidString.prefix(8)).lowercased())] Agent unregistered")
        return true
    }

    /// Find an agent by name or ID (global search, used for registration/unregistration)
    func findAgent(byNameOrId identifier: String) async -> Agent? {
        guard let provider = agentDataProvider else { return nil }
        let agents = await provider.getAgents()

        // Try UUID first
        if let uuid = UUID(uuidString: identifier) {
            return agents.first { $0.id == uuid }
        }

        // Try name (case-insensitive)
        return agents.first { $0.name.lowercased() == identifier.lowercased() }
    }

    /// Find an agent by name or ID, but only within the same workspace as the caller
    func findAgentInSameWorkspace(callerAgentId: UUID, identifier: String) async -> Agent? {
        guard let provider = agentDataProvider else { return nil }
        let agents = await provider.getAgentsInSameWorkspace(as: callerAgentId)

        // Try UUID first
        if let uuid = UUID(uuidString: identifier) {
            return agents.first { $0.id == uuid }
        }

        // Try name (case-insensitive)
        return agents.first { $0.name.lowercased() == identifier.lowercased() }
    }

    // MARK: - Message Operations

    /// Returns nil on success, or an error message string on failure
    func sendMessage(from: String, to: String, content: String) async -> String? {
        // Verify sender exists and is registered
        guard let sender = await findAgent(byNameOrId: from) else {
            logger.warning("[skwad] Sender not found: \(from)")
            return "Sender not found"
        }

        guard sender.isRegistered else {
            logger.warning("[skwad] Sender not registered: \(from)")
            return "Sender not registered"
        }

        // Find recipient - must be in same workspace as sender
        guard let recipient = await findAgentInSameWorkspace(callerAgentId: sender.id, identifier: to) else {
            logger.warning("[skwad] Recipient not found in same workspace: \(to)")
            return "Recipient not found"
        }

        // Cannot send messages to shell agents
        if recipient.isShell {
            logger.warning("[skwad] Cannot send message to shell agent: \(to)")
            return "Cannot send messages to shell agents"
        }

        // Only the owner can send messages to a companion agent
        if recipient.isCompanion && recipient.createdBy != sender.id {
            logger.warning("[skwad] Non-owner tried to message companion agent: \(to)")
            return "Only the owner can send messages to a companion agent"
        }

        // Companions can only send messages to their owner
        if sender.isCompanion && recipient.id != sender.createdBy {
            logger.warning("[skwad] Companion tried to message non-owner: \(to)")
            return "Companion agents can only send messages to their owner"
        }

        // Create and store message
        let message = MCPMessage(
            from: sender.id.uuidString,
            to: recipient.id.uuidString,
            content: content
        )
        await messageStore.add(message)

        // If recipient is idle, notify them they have a message
        if recipient.status == .idle {
            await notifyAgentOfMessage(recipient, messageId: message.id)
        }

        return nil
    }

    private func notifyAgentOfMessage(_ agent: Agent, messageId: UUID) async {
        guard let provider = agentDataProvider else { return }
        await provider.injectText("Check your inbox for messages from other agents", for: agent.id)
    }

    func checkMessages(for agentId: String, markAsRead: Bool = true) async -> [MCPMessage] {
        guard let agent = await findAgent(byNameOrId: agentId) else {
            logger.warning("[skwad] Agent not found for check-messages: \(agentId)")
            return []
        }

        let agentUUID = agent.id.uuidString
        let unread = await messageStore.getUnread(for: agentUUID)

        if markAsRead {
            await messageStore.markAsRead(for: agentUUID)
        }

        return unread
    }

    func broadcastMessage(from: String, content: String) async -> Int {
        guard let sender = await findAgent(byNameOrId: from) else {
            logger.warning("[skwad] Sender not found for broadcast: \(from)")
            return 0
        }

        guard sender.isRegistered else {
            logger.warning("[skwad] Sender not registered for broadcast: \(from)")
            return 0
        }

        guard let provider = agentDataProvider else { return 0 }

        // Only broadcast to agents in the same workspace
        let agents = await provider.getAgentsInSameWorkspace(as: sender.id)

        var count = 0
        var recipients: [(Agent, UUID)] = []

        for agent in agents where agent.id != sender.id && agent.isRegistered && !agent.isShell
            && (!agent.isCompanion || agent.createdBy == sender.id)
            && (!sender.isCompanion || agent.id == sender.createdBy) {
            let message = MCPMessage(
                from: sender.id.uuidString,
                to: agent.id.uuidString,
                content: content
            )
            await messageStore.add(message)
            recipients.append((agent, message.id))
            count += 1
        }

        // Notify all recipients to check their inbox
        for (agent, messageId) in recipients {
            await notifyAgentOfMessage(agent, messageId: messageId)
        }

        return count
    }

    func hasUnreadMessages(for agentId: String) async -> Bool {
        guard let agent = await findAgent(byNameOrId: agentId) else {
            return false
        }
        let agentUUID = agent.id.uuidString
        return await messageStore.hasUnread(for: agentUUID)
    }

    func getLatestUnreadMessageId(for agentId: String) async -> UUID? {
        guard let agent = await findAgent(byNameOrId: agentId) else {
            return nil
        }
        let agentUUID = agent.id.uuidString
        return await messageStore.getLatestUnreadId(for: agentUUID)
    }

    // MARK: - Session Management

    func getSession(id: String) async -> MCPSession? {
        await sessionManager.getSession(id: id)
    }

    func createSession(for agentId: UUID) async -> MCPSession {
        await sessionManager.createSession(for: agentId)
    }

    // MARK: - Helper to get sender name from ID

    func getAgentName(for agentId: String) async -> String? {
        guard let agent = await findAgent(byNameOrId: agentId) else {
            return nil
        }
        return agent.name
    }

    /// Get all agents for recovery purposes (when an agent forgets its ID)
    func getAllAgentsForRecovery() async -> [AgentInfo] {
        guard let provider = agentDataProvider else { return [] }

        let agents = await provider.getAgents()
        return agents.map { agent in
            AgentInfo(
                id: agent.id.uuidString,
                name: agent.name,
                folder: agent.folder,
                status: agent.status.rawValue,
                isRegistered: agent.isRegistered
            )
        }
    }

    // MARK: - Repository Operations

    func listRepos() async -> [RepoInfoResponse] {
        let repos = await MainActor.run {
            RepoDiscoveryService.shared.repos
        }
        return repos.map { repo in
            RepoInfoResponse(
                name: repo.name,
                worktrees: repo.worktrees.map { wt in
                    WorktreeInfoResponse(name: wt.name, path: wt.path)
                }
            )
        }
    }

    // MARK: - Agent Creation

    func createAgent(
        name: String,
        icon: String?,
        agentType: String,
        repoPath: String,
        createWorktree: Bool,
        branchName: String?,
        createdBy: UUID?,
        companion: Bool,
        shellCommand: String?
    ) async -> CreateAgentResponse {
        guard let provider = agentDataProvider else {
            return CreateAgentResponse(success: false, agentId: nil, message: "AgentDataProvider not available")
        }

        var folder = repoPath

        // Create worktree if requested
        if createWorktree {
            guard let branch = branchName, !branch.isEmpty else {
                return CreateAgentResponse(success: false, agentId: nil, message: "branchName is required when createWorktree is true")
            }

            // Verify repo exists
            guard GitWorktreeManager.shared.isGitRepo(repoPath) else {
                return CreateAgentResponse(success: false, agentId: nil, message: "Repository not found at path: \(repoPath)")
            }

            // Generate destination path for worktree
            let destinationPath = GitWorktreeManager.shared.suggestedWorktreePath(repoPath: repoPath, branchName: branch)

            // Check if destination already exists
            if FileManager.default.fileExists(atPath: destinationPath) {
                return CreateAgentResponse(success: false, agentId: nil, message: "Worktree destination already exists: \(destinationPath)")
            }

            do {
                try GitWorktreeManager.shared.createWorktree(
                    repoPath: repoPath,
                    branchName: branch,
                    destinationPath: destinationPath
                )
                folder = destinationPath
                logger.info("[skwad] Created worktree at \(destinationPath) for branch \(branch)")
            } catch {
                return CreateAgentResponse(success: false, agentId: nil, message: "Failed to create worktree: \(error.localizedDescription)")
            }
        } else {
            // Verify folder exists
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue else {
                return CreateAgentResponse(success: false, agentId: nil, message: "Folder not found: \(folder)")
            }
        }

        // Enforce max 3 companions per owner
        if companion, let ownerId = createdBy {
            let agents = await provider.getAgents()
            let existingCompanions = agents.filter { $0.createdBy == ownerId && $0.isCompanion }
            if existingCompanions.count >= 3 {
                return CreateAgentResponse(success: false, agentId: nil, message: "Maximum of 3 companion agents per owner reached")
            }
        }

        // Create the agent via the provider
        if let agentId = await provider.addAgent(folder: folder, name: name, avatar: icon, agentType: agentType, createdBy: createdBy, companion: companion, shellCommand: shellCommand) {
            logger.info("[skwad] Created agent '\(name)' with ID \(agentId)")
            return CreateAgentResponse(success: true, agentId: agentId.uuidString, message: "Agent created successfully")
        } else {
            return CreateAgentResponse(success: false, agentId: nil, message: "Failed to create agent")
        }
    }

    // MARK: - Agent Closing

    func closeAgent(callerAgentId: UUID, targetIdentifier: String) async -> CloseAgentResponse {
        guard let provider = agentDataProvider else {
            return CloseAgentResponse(success: false, message: "AgentDataProvider not available")
        }

        // Find the target agent in the same workspace as the caller
        guard let targetAgent = await findAgentInSameWorkspace(callerAgentId: callerAgentId, identifier: targetIdentifier) else {
            return CloseAgentResponse(success: false, message: "Target agent not found: \(targetIdentifier)")
        }

        // Verify the caller created the target agent
        guard targetAgent.createdBy == callerAgentId else {
            return CloseAgentResponse(success: false, message: "Permission denied: you can only close agents that you created")
        }

        // Close the agent
        let success = await provider.removeAgent(id: targetAgent.id)
        if success {
            logger.info("[skwad] Agent '\(targetAgent.name)' closed by \(callerAgentId)")
            return CloseAgentResponse(success: true, message: "Agent '\(targetAgent.name)' closed successfully")
        } else {
            return CloseAgentResponse(success: false, message: "Failed to close agent")
        }
    }

    // MARK: - Markdown Panel

    func showMarkdownPanel(filePath: String, agentId: UUID) async -> Bool {
        guard let provider = agentDataProvider else {
            logger.error("[skwad] AgentDataProvider not available for showMarkdownPanel")
            return false
        }
        return await provider.showMarkdownPanel(filePath: filePath, agentId: agentId)
    }

    // MARK: - Cleanup

    func cleanup() async {
        await sessionManager.cleanupStaleSessions()
        await messageStore.cleanup()
    }
}

// MARK: - Agent Manager Wrapper

/// Wrapper that safely bridges MainActor-isolated AgentManager to the MCPService actor
/// All calls go through proper async boundaries
final class AgentManagerWrapper: AgentDataProvider, @unchecked Sendable {
    private weak var manager: AgentManager?

    init(manager: AgentManager) {
        self.manager = manager
    }

    func getAgents() async -> [Agent] {
        await MainActor.run {
            manager?.agents ?? []
        }
    }

    func getAgent(id: UUID) async -> Agent? {
        await MainActor.run {
            manager?.agents.first { $0.id == id }
        }
    }

    func getAgentsInSameWorkspace(as agentId: UUID) async -> [Agent] {
        await MainActor.run {
            guard let manager = manager else { return [] }

            // Find which workspace contains this agent
            guard let workspace = manager.workspaces.first(where: {
                $0.agentIds.contains(agentId)
            }) else {
                return []  // Agent not in any workspace
            }

            // Return all agents in that workspace
            return workspace.agentIds.compactMap { id in
                manager.agents.first { $0.id == id }
            }
        }
    }

    func setRegistered(for agentId: UUID, registered: Bool) async {
        await MainActor.run {
            manager?.setRegistered(for: agentId, registered: registered)
        }
    }

    func injectText(_ text: String, for agentId: UUID) async {
        await MainActor.run {
            manager?.injectText(text, for: agentId)
        }
    }

    func addAgent(folder: String, name: String, avatar: String?, agentType: String, createdBy: UUID?, companion: Bool, shellCommand: String?) async -> UUID? {
        await MainActor.run {
            guard let manager = manager else { return nil }
            guard let newAgentId = manager.addAgent(folder: folder, name: name, avatar: avatar, agentType: agentType, createdBy: createdBy, isCompanion: companion, shellCommand: shellCommand) else {
                return nil
            }

            // If companion and creator is currently displayed, enter split with owner
            if companion, let creatorId = createdBy, manager.activeAgentIds.contains(creatorId) {
                manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)
            }

            return newAgentId
        }
    }

    func removeAgent(id: UUID) async -> Bool {
        await MainActor.run {
            guard let manager = manager,
                  let agent = manager.agents.first(where: { $0.id == id }) else {
                return false
            }
            manager.removeAgent(agent)
            return true
        }
    }

    func showMarkdownPanel(filePath: String, agentId: UUID) async -> Bool {
        await MainActor.run {
            guard let manager = manager else { return false }
            manager.showMarkdownPanel(filePath: filePath, forAgent: agentId)
            return true
        }
    }
}
