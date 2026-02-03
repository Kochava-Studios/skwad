import Foundation
import Logging

// MARK: - MCP Service Protocol

protocol MCPServiceProtocol {
    func listAgents(callerAgentId: String) async -> [AgentInfo]
    func registerAgent(agentId: String) async -> Bool
    func unregisterAgent(agentId: String) async -> Bool
    func sendMessage(from: String, to: String, content: String) async -> Bool
    func checkMessages(for agentId: String, markAsRead: Bool) async -> [MCPMessage]
    func broadcastMessage(from: String, content: String) async -> Int
    func hasUnreadMessages(for agentId: String) async -> Bool
}

// MARK: - Agent Data Provider Protocol
// Allows MCPService to query agent data without holding a reference to AgentManager

protocol AgentDataProvider: Sendable {
    func getAgents() async -> [Agent]
    func getAgentsInSameWorkspace(as agentId: UUID) async -> [Agent]
    func setRegistered(for agentId: UUID, registered: Bool) async
    func injectText(_ text: String, for agentId: UUID) async
    func addAgent(folder: String, name: String, avatar: String?, agentType: String) async -> UUID?
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
        let agents = await provider.getAgentsInSameWorkspace(as: callerUUID)
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

    func sendMessage(from: String, to: String, content: String) async -> Bool {
        // Verify sender exists and is registered
        guard let sender = await findAgent(byNameOrId: from) else {
            logger.warning("[skwad] Sender not found: \(from)")
            return false
        }

        guard sender.isRegistered else {
            logger.warning("[skwad] Sender not registered: \(from)")
            return false
        }

        // Find recipient - must be in same workspace as sender
        guard let recipient = await findAgentInSameWorkspace(callerAgentId: sender.id, identifier: to) else {
            logger.warning("[skwad] Recipient not found in same workspace: \(to)")
            return false
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

        return true
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

        for agent in agents where agent.id != sender.id && agent.isRegistered {
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
        let baseFolder = await MainActor.run {
            AppSettings.shared.expandedSourceBaseFolder
        }

        guard !baseFolder.isEmpty else {
            logger.warning("[skwad] Source base folder not configured")
            return []
        }

        let repos = GitWorktreeManager.shared.discoverRepos(in: baseFolder)
        return repos.map { repo in
            RepoInfoResponse(
                name: repo.name,
                path: repo.path,
                worktreeCount: repo.worktreeCount
            )
        }
    }

    func listWorktrees(for repoPath: String) -> [WorktreeInfoResponse] {
        let worktrees = GitWorktreeManager.shared.listWorktrees(for: repoPath)
        return worktrees.map { wt in
            WorktreeInfoResponse(
                path: wt.path,
                branch: wt.branch,
                isMain: wt.isMain
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
        branchName: String?
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

            // Check if branch exists locally or remotely
            let localBranches = GitWorktreeManager.shared.listLocalBranches(for: repoPath)
            let remoteBranches = GitWorktreeManager.shared.listRemoteBranches(for: repoPath)
            let branchExists = localBranches.contains(branch) || remoteBranches.contains(branch)

            do {
                try GitWorktreeManager.shared.createWorktree(
                    repoPath: repoPath,
                    branchName: branch,
                    destinationPath: destinationPath,
                    createBranch: !branchExists
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

        // Create the agent via the provider
        if let agentId = await provider.addAgent(folder: folder, name: name, avatar: icon, agentType: agentType) {
            logger.info("[skwad] Created agent '\(name)' with ID \(agentId)")
            return CreateAgentResponse(success: true, agentId: agentId.uuidString, message: "Agent created successfully")
        } else {
            return CreateAgentResponse(success: false, agentId: nil, message: "Failed to create agent")
        }
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

    func addAgent(folder: String, name: String, avatar: String?, agentType: String) async -> UUID? {
        await MainActor.run {
            guard let manager = manager else { return nil }
            let countBefore = manager.agents.count
            manager.addAgent(folder: folder, name: name, avatar: avatar, agentType: agentType)
            // Return the ID of the newly added agent
            if manager.agents.count > countBefore {
                return manager.agents.last?.id
            }
            return nil
        }
    }
}
