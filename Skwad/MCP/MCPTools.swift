import Foundation

// MARK: - MCP Tool Handler

actor MCPToolHandler {
    private let mcpService: AgentCoordinator

    init(mcpService: AgentCoordinator) {
        self.mcpService = mcpService
    }

    // MARK: - Tool Definitions

    func listTools() -> [ToolDefinition] {
        [
            ToolDefinition(
                name: MCPToolName.registerAgent.rawValue,
                description: "Register this agent with Skwad crew. Call this first before using other tools.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "The agent ID provided by Skwad"),
                        "sessionId": PropertySchema(type: "string", description: "Your internal session ID.")
                    ],
                    required: ["agentId"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.listAgents.rawValue,
                description: "List all registered agents with their status (name, folder, working/idle)",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID")
                    ],
                    required: ["agentId"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.sendMessage.rawValue,
                description: "Send a message to another agent by name or ID",
                inputSchema: ToolInputSchema(
                    properties: [
                        "from": PropertySchema(type: "string", description: "Your agent ID"),
                        "to": PropertySchema(type: "string", description: "Recipient agent name or ID"),
                        "content": PropertySchema(type: "string", description: "Message content")
                    ],
                    required: ["from", "to", "content"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.checkMessages.rawValue,
                description: AgentPrompts.checkInbox,
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID"),
                        "markAsRead": PropertySchema(type: "boolean", description: "Mark messages as read (default: true)")
                    ],
                    required: ["agentId"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.broadcastMessage.rawValue,
                description: "Send a message to all other registered agents",
                inputSchema: ToolInputSchema(
                    properties: [
                        "from": PropertySchema(type: "string", description: "Your agent ID"),
                        "content": PropertySchema(type: "string", description: "Message content")
                    ],
                    required: ["from", "content"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.listRepos.rawValue,
                description: "List all git repositories in the configured source folder",
                inputSchema: ToolInputSchema(
                    properties: [:],
                    required: []
                )
            ),
            ToolDefinition(
                name: MCPToolName.listWorktrees.rawValue,
                description: "List all worktrees for a given repository",
                inputSchema: ToolInputSchema(
                    properties: [
                        "repoPath": PropertySchema(type: "string", description: "Path to the repository")
                    ],
                    required: ["repoPath"]
                )
            ),
            createAgentToolDefinition(),
            ToolDefinition(
                name: MCPToolName.closeAgent.rawValue,
                description: "Close an agent that you created. You can only close agents that you created, not agents created by the user or other agents.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID"),
                        "target": PropertySchema(type: "string", description: "The agent to close (name or ID)")
                    ],
                    required: ["agentId", "target"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.createWorktree.rawValue,
                description: "Create a new git worktree from a repository. Returns the path to the new worktree.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "repoPath": PropertySchema(type: "string", description: "Path to the source repository"),
                        "branchName": PropertySchema(type: "string", description: "Branch name for the new worktree")
                    ],
                    required: ["repoPath", "branchName"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.setStatus.rawValue,
                description: "MANDATORY: Set your status so other agents know what you are doing. Call before starting any task, after completing it, and when changing direction. Keep it short and specific (e.g. 'Implementing auth module', 'Running tests', 'Done — PR ready'). Use empty string to clear.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID"),
                        "status": PropertySchema(type: "string", description: "Short status text describing what you are currently doing. Use empty string to clear.")
                    ],
                    required: ["agentId", "status"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.displayMarkdown.rawValue,
                description: "Display a markdown file in a panel for the user to review. Use this to show plans, documentation, or any markdown content that needs user attention. Also use if the user asks you to show him a file. Never assume the panel is open or displaying the right file as the user may have closed it: call the tool again when relevant.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID"),
                        "filePath": PropertySchema(type: "string", description: "Absolute path to the markdown file to display"),
                        "maximized": PropertySchema(type: "boolean", description: "If true, maximize the panel to fill the available space. Only set to true if the user explicitly requests it. Default: false")
                    ],
                    required: ["agentId", "filePath"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.viewMermaid.rawValue,
                description: "Display a Mermaid diagram in a panel for the user to view. Supports flowcharts (graph TD/LR), state diagrams, sequence diagrams, class diagrams, and ER diagrams. Pass the mermaid source text directly. The diagram will be rendered natively alongside any open markdown panel. Not supported: HTML in node labels, tooltips, multiline labels with <br> tags, styling via style and linkStyle directives, subgraph styling.",
                inputSchema: ToolInputSchema(
                    properties: [
                        "agentId": PropertySchema(type: "string", description: "Your agent ID"),
                        "source": PropertySchema(type: "string", description: "Mermaid diagram source text (e.g. 'graph TD; A-->B;')"),
                        "title": PropertySchema(type: "string", description: "Optional title to display above the diagram")
                    ],
                    required: ["agentId", "source"]
                )
            )
        ]
    }

    private func createAgentToolDefinition() -> ToolDefinition {
        let personas = AppSettings.shared.personas
        let benchAgents = AppSettings.shared.benchAgents
        var description = "Create a new agent in Skwad. Can optionally create a new git worktree for the agent. Note: shell agents are plain terminals without an AI agent, so do not try to send messages to them."
        if !benchAgents.isEmpty {
            let benchList = benchAgents.map { "\($0.name) [\($0.agentType)] at \($0.folder) (ID: \($0.id.uuidString))" }.joined(separator: ", ")
            description += " Bench agents (pre-configured templates, prefer these when possible): \(benchList)."
        }
        var personaIdDescription = "ID of a persona to apply. Only works with agents that support system prompts (claude, codex)."
        if !personas.isEmpty {
            let personaList = personas.map { "\($0.name) (\($0.id.uuidString))" }.joined(separator: ", ")
            description += " Available personas: \(personaList)."
            personaIdDescription += " Available: \(personaList)."
        }
        return ToolDefinition(
            name: MCPToolName.createAgent.rawValue,
            description: description,
            inputSchema: ToolInputSchema(
                properties: [
                    "agentId": PropertySchema(type: "string", description: "Your agent ID (used to track who created the agent)"),
                    "benchAgentId": PropertySchema(type: "string", description: "ID of a bench agent to deploy. When provided, name/agentType/repoPath are optional and default to the bench agent's configuration."),
                    "name": PropertySchema(type: "string", description: "Name for the agent"),
                    "icon": PropertySchema(type: "string", description: "Emoji icon for the agent (e.g., '🤖')"),
                    "agentType": PropertySchema(type: "string", description: "Agent type: claude, codex, opencode, gemini, copilot, custom1, custom2, or shell"),
                    "repoPath": PropertySchema(type: "string", description: "Path to the repository or worktree folder"),
                    "createWorktree": PropertySchema(type: "boolean", description: "If true, create a new worktree from repoPath"),
                    "branchName": PropertySchema(type: "string", description: "Branch name for new worktree (required if createWorktree is true)"),
                    "companion": PropertySchema(type: "boolean", description: "If true, the new agent is a companion of the creator: it won't appear in the agent list, its visibility is linked to the creator, and it will be closed when the creator is closed. Only use this flag if the user has explicitly asked for a companion agent."),
                    "command": PropertySchema(type: "string", description: "Command to run (only for shell agent type)"),
                    "personaId": PropertySchema(type: "string", description: personaIdDescription)
                ],
                required: ["agentId"]
            )
        )
    }

    // MARK: - Tool Execution

    func callTool(name: String, arguments: [String: Any]) async -> ToolCallResult {
        guard let toolName = MCPToolName(rawValue: name) else {
            return errorResult("Unknown tool: \(name)")
        }

        switch toolName {
        case .registerAgent:
            return await handleRegisterAgent(arguments)
        case .listAgents:
            return await handleListAgents(arguments)
        case .sendMessage:
            return await handleSendMessage(arguments)
        case .checkMessages:
            return await handleCheckMessages(arguments)
        case .broadcastMessage:
            return await handleBroadcastMessage(arguments)
        case .listRepos:
            return await handleListRepos(arguments)
        case .listWorktrees:
            return await handleListWorktrees(arguments)
        case .createAgent:
            return await handleCreateAgent(arguments)
        case .closeAgent:
            return await handleCloseAgent(arguments)
        case .setStatus:
            return await handleSetStatus(arguments)
        case .createWorktree:
            return await handleCreateWorktree(arguments)
        case .displayMarkdown:
            return await handleDisplayMarkdown(arguments)
        case .viewMermaid:
            return await handleViewMermaid(arguments)
        }
    }

    // MARK: - Tool Implementations

    private func handleRegisterAgent(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }

        let sessionId = arguments["sessionId"] as? String
        let success = await mcpService.registerAgent(agentId: agentId, sessionId: sessionId)

        if success {
            // Get skwad members for context
            let members = await mcpService.listAgents(callerAgentId: agentId)

            let response = RegisterAgentResponse(
                success: true,
                message: "Successfully registered with Skwad crew. Note: skwad members can change over time as agents join or leave. Use list-agents to get the current list.",
                unreadMessageCount: 0,
                skwadMembers: members
            )
            return successResult(response)
        } else {
            return errorResult("Failed to register: agent not found or invalid ID")
        }
    }

    private func handleListAgents(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }

        // Check if caller exists
        let callerExists = await mcpService.findAgent(byNameOrId: agentId) != nil
        if !callerExists {
            return await agentNotFoundError(agentId)
        }

        let agents = await mcpService.listAgents(callerAgentId: agentId)
        let response = ListAgentsResponse(agents: agents)
        return successResult(response)
    }

    private func handleSendMessage(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let to = arguments["to"] as? String else {
            return errorResult("Missing required parameter: to")
        }
        guard let content = arguments["content"] as? String else {
            return errorResult("Missing required parameter: content")
        }

        // The 'from' should be inferred from the calling agent's session
        // For now, we require it to be passed or extracted from context
        guard let from = arguments["from"] as? String else {
            return errorResult("Missing required parameter: from (your agent ID)")
        }

        // Check if sender exists before attempting to send
        let senderExists = await mcpService.findAgent(byNameOrId: from) != nil
        if !senderExists {
            return await agentNotFoundError(from)
        }

        if let error = await mcpService.sendMessage(from: from, to: to, content: content) {
            return errorResult("Failed to send message: \(error)")
        }

        let response = SendMessageResponse(success: true, message: "Message sent successfully. Don't check for a response right away - you will be notified when the other agent responds.")
        return successResult(response)
    }

    private func handleCheckMessages(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }

        // Check if caller exists
        let callerExists = await mcpService.findAgent(byNameOrId: agentId) != nil
        if !callerExists {
            return await agentNotFoundError(agentId)
        }

        let markAsRead = (arguments["markAsRead"] as? Bool) ?? true
        let messages = await mcpService.checkMessages(for: agentId, markAsRead: markAsRead)

        // Convert to response format with sender names
        var messageInfos: [MessageInfo] = []
        for message in messages {
            let senderName = await mcpService.getAgentName(for: message.from) ?? message.from
            let info = MessageInfo(
                id: message.id.uuidString,
                from: senderName,
                content: message.content,
                timestamp: ISO8601DateFormatter().string(from: message.timestamp)
            )
            messageInfos.append(info)
        }

        let response = CheckMessagesResponse(messages: messageInfos)
        return successResult(response)
    }

    private func handleBroadcastMessage(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let from = arguments["from"] as? String else {
            return errorResult("Missing required parameter: from")
        }
        guard let content = arguments["content"] as? String else {
            return errorResult("Missing required parameter: content")
        }

        // Check if sender exists
        let senderExists = await mcpService.findAgent(byNameOrId: from) != nil
        if !senderExists {
            return await agentNotFoundError(from)
        }

        let count = await mcpService.broadcastMessage(from: from, content: content)
        let response = BroadcastResponse(success: count > 0, recipientCount: count)
        return successResult(response)
    }

    private func handleListRepos(_ arguments: [String: Any]) async -> ToolCallResult {
        let repos = await mcpService.listRepos()
        let response = ListReposResponse(repos: repos)
        return successResult(response)
    }

    private func handleListWorktrees(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let repoPath = arguments["repoPath"] as? String else {
            return errorResult("Missing required parameter: repoPath")
        }

        let repos = await MainActor.run { RepoDiscoveryService.shared.repos }
        let repo = repos.first { $0.path == repoPath }
        let worktrees = repo?.worktrees ?? []
        let response = ListWorktreesResponse(repoPath: repoPath, worktrees: worktrees.map {
            WorktreeInfoResponse(name: $0.name, path: $0.path)
        })
        return successResult(response)
    }

    private func handleCreateAgent(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentIdString = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }

        // Resolve bench agent defaults if provided
        var benchAgent: BenchAgent?
        if let benchAgentIdString = arguments["benchAgentId"] as? String,
           let benchAgentId = UUID(uuidString: benchAgentIdString) {
            let benchAgents = await MainActor.run { AppSettings.shared.benchAgents }
            guard let found = benchAgents.first(where: { $0.id == benchAgentId }) else {
                return errorResult("Bench agent not found: \(benchAgentIdString)")
            }
            benchAgent = found
        }

        // Use explicit params with bench agent as fallback
        let name = arguments["name"] as? String ?? benchAgent?.name
        let icon = arguments["icon"] as? String ?? benchAgent?.avatar
        let agentType = arguments["agentType"] as? String ?? benchAgent?.agentType
        let repoPath = arguments["repoPath"] as? String ?? benchAgent?.folder

        var missing: [String] = []
        if name == nil { missing.append("name") }
        if agentType == nil { missing.append("agentType") }
        if repoPath == nil { missing.append("repoPath") }
        if !missing.isEmpty {
            return errorResult("Missing required parameters: \(missing.joined(separator: ", ")). Provide these or use benchAgentId to deploy from a template.")
        }

        guard let name, let agentType, let repoPath else {
            return errorResult("Missing required parameters: name, agentType, repoPath")
        }

        let createWorktree = arguments["createWorktree"] as? Bool ?? false
        let branchName = arguments["branchName"] as? String
        let companion = arguments["companion"] as? Bool ?? false
        let shellCommand = arguments["command"] as? String ?? benchAgent?.shellCommand
        let personaId = (arguments["personaId"] as? String).flatMap { UUID(uuidString: $0) } ?? benchAgent?.personaId

        // Validate branch name is provided if creating worktree
        if createWorktree && (branchName == nil || branchName!.isEmpty) {
            return errorResult("branchName is required when createWorktree is true")
        }

        let createdBy = UUID(uuidString: agentIdString)

        let result = await mcpService.createAgent(
            name: name,
            icon: icon,
            agentType: agentType,
            repoPath: repoPath,
            createWorktree: createWorktree,
            branchName: branchName,
            createdBy: createdBy,
            companion: companion,
            shellCommand: shellCommand,
            personaId: personaId
        )

        return successResult(result)
    }

    private func handleCloseAgent(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentIdString = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }
        guard let agentId = UUID(uuidString: agentIdString) else {
            return errorResult("Invalid agentId format")
        }
        guard let target = arguments["target"] as? String else {
            return errorResult("Missing required parameter: target")
        }

        // Check if caller exists and is registered
        guard let caller = await mcpService.findAgent(byNameOrId: agentIdString) else {
            return await agentNotFoundError(agentIdString)
        }
        guard caller.isRegistered else {
            return errorResult("You must be registered to close agents")
        }

        let result = await mcpService.closeAgent(callerAgentId: agentId, targetIdentifier: target)
        return successResult(result)
    }

    private func handleSetStatus(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentIdString = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }
        guard let status = arguments["status"] as? String else {
            return errorResult("Missing required parameter: status")
        }

        guard let agent = await mcpService.findAgent(byNameOrId: agentIdString) else {
            return await agentNotFoundError(agentIdString)
        }

        await mcpService.setAgentStatus(for: agent.id, status: status)
        return successResult("Status updated")
    }

    private func handleCreateWorktree(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let repoPath = arguments["repoPath"] as? String else {
            return errorResult("Missing required parameter: repoPath")
        }
        guard let branchName = arguments["branchName"] as? String, !branchName.isEmpty else {
            return errorResult("Missing required parameter: branchName")
        }

        let manager = GitWorktreeManager.shared
        guard manager.isGitRepo(repoPath) else {
            return errorResult("Not a git repository: \(repoPath)")
        }

        let worktreePath = manager.suggestedWorktreePath(repoPath: repoPath, branchName: branchName)
        do {
            try manager.createWorktree(repoPath: repoPath, branchName: branchName, destinationPath: worktreePath)
            return successResult(CreateWorktreeResponse(success: true, path: worktreePath, message: "Worktree created at \(worktreePath)"))
        } catch {
            return errorResult("Failed to create worktree: \(error.localizedDescription)")
        }
    }

    private func handleDisplayMarkdown(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }
        guard let filePath = arguments["filePath"] as? String else {
            return errorResult("Missing required parameter: filePath")
        }

        // Verify agent exists
        guard let agent = await mcpService.findAgent(byNameOrId: agentId) else {
            return await agentNotFoundError(agentId)
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            return errorResult("File not found: \(filePath)")
        }

        // Request the markdown panel to be shown
        let maximized = arguments["maximized"] as? Bool ?? false
        let success = await mcpService.showMarkdownPanel(filePath: filePath, maximized: maximized, agentId: agent.id)

        if success {
            let response = ShowMarkdownResponse(
                success: true,
                message: "Markdown panel opened for: \(filePath). Inform the user they can highlight text in the preview to make comments, then click 'Submit Review' to send them to you."
            )
            return successResult(response)
        } else {
            return errorResult("Failed to open markdown panel")
        }
    }

    private func handleViewMermaid(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }
        guard let source = arguments["source"] as? String else {
            return errorResult("Missing required parameter: source")
        }

        // Verify agent exists
        guard let agent = await mcpService.findAgent(byNameOrId: agentId) else {
            return await agentNotFoundError(agentId)
        }

        let title = arguments["title"] as? String
        let success = await mcpService.showMermaidPanel(source: source, title: title, agentId: agent.id)

        if success {
            let response = ShowMermaidResponse(
                success: true,
                message: "Mermaid diagram panel opened. Supported diagram types: flowcharts, state, sequence, class, and ER diagrams."
            )
            return successResult(response)
        } else {
            return errorResult("Failed to open mermaid panel")
        }
    }

    // MARK: - Helpers

    private func agentNotFoundError(_ providedId: String) async -> ToolCallResult {
        // Get all agents to help the caller find themselves
        let agents = await mcpService.getAllAgentsForRecovery()

        var message = "Agent ID '\(providedId)' not found. "

        if agents.isEmpty {
            message += "No agents are currently available. Ask the user to check if Skwad is running correctly."
        } else {
            message += "You may have forgotten your ID due to context loss. Here are all agents - find yourself by matching your working directory:\n\n"
            for agent in agents {
                message += "- \(agent.name): \(agent.folder) (ID: \(agent.id))\n"
            }
            message += "\nIf you're unsure which one you are, ask the user to right-click on your agent in Skwad and select 'Register'."
        }

        return errorResult(message)
    }

    private func successResult<T: Codable>(_ result: T) -> ToolCallResult {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            let text = String(data: data, encoding: .utf8) ?? "{}"
            return ToolCallResult(content: [ToolContent(text: text)], isError: false)
        } catch {
            return errorResult("Failed to encode result: \(error.localizedDescription)")
        }
    }

    private func errorResult(_ message: String) -> ToolCallResult {
        ToolCallResult(content: [ToolContent(text: message)], isError: true)
    }
}
