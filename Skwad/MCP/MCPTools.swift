import Foundation

// MARK: - MCP Tool Handler

actor MCPToolHandler {
    private let mcpService: MCPService

    init(mcpService: MCPService) {
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
                        "agentId": PropertySchema(type: "string", description: "The agent ID provided by Skwad")
                    ],
                    required: ["agentId"]
                )
            ),
            ToolDefinition(
                name: MCPToolName.listAgents.rawValue,
                description: "List all registered agents with their status (name, folder, working/idle)",
                inputSchema: ToolInputSchema()
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
                description: "Check your inbox for messages from other agents",
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
            )
        ]
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
            return await handleListAgents()
        case .sendMessage:
            return await handleSendMessage(arguments)
        case .checkMessages:
            return await handleCheckMessages(arguments)
        case .broadcastMessage:
            return await handleBroadcastMessage(arguments)
        }
    }

    // MARK: - Tool Implementations

    private func handleRegisterAgent(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
        }

        let success = await mcpService.registerAgent(agentId: agentId)

        if success {
            let response = RegisterAgentResponse(
                success: true,
                message: "Successfully registered with Skwad crew"
            )
            return successResult(response)
        } else {
            return errorResult("Failed to register: agent not found or invalid ID")
        }
    }

    private func handleListAgents() async -> ToolCallResult {
        let agents = await mcpService.listAgents()
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

        let success = await mcpService.sendMessage(from: from, to: to, content: content)

        if success {
            let response = SendMessageResponse(success: true, message: "Message sent successfully")
            return successResult(response)
        } else {
            return errorResult("Failed to send message: recipient not found or sender not registered")
        }
    }

    private func handleCheckMessages(_ arguments: [String: Any]) async -> ToolCallResult {
        guard let agentId = arguments["agentId"] as? String else {
            return errorResult("Missing required parameter: agentId")
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

        let count = await mcpService.broadcastMessage(from: from, content: content)
        let response = BroadcastResponse(success: count > 0, recipientCount: count)
        return successResult(response)
    }

    // MARK: - Helpers

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
