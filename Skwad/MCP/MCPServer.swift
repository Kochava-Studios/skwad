import Foundation
import Hummingbird
import Logging

// MARK: - MCP Server

actor MCPServer: MCPTransportProtocol {
    private let port: Int
    private let logger = Logger(label: "com.skwad.mcp.server")
    private var app: Application<RouterResponder<BasicRequestContext>>?
    private var serverTask: Task<Void, Error>?
    private let mcpService: MCPService
    private let toolHandler: MCPToolHandler

    init(port: Int = 8766, mcpService: MCPService = .shared) {
        self.port = port
        self.mcpService = mcpService
        self.toolHandler = MCPToolHandler(mcpService: mcpService)
    }

    func start() async throws {
        let router = Router()

        // Health check endpoint
        router.get("/health") { _, _ in
            Response(status: .ok, body: .init(byteBuffer: .init(string: "OK")))
        }

        // Debug status endpoint
        router.get("/status") { [self] request, context in
            await handleStatus(request, context: context)
        }

        // MCP endpoint - POST for JSON-RPC requests
        router.post("/mcp") { [self] request, context in
            await handleMCPRequest(request, context: context)
        }

        // MCP endpoint - GET for SSE (Server-Sent Events)
        router.get("/mcp") { [self] request, context in
            await handleSSERequest(request, context: context)
        }

        // Hook-based agent registration endpoint
        router.post("/api/v1/agent/register") { [self] request, context in
            await handleHookRegister(request, context: context)
        }

        // Hook-based activity status endpoint
        router.post("/api/v1/agent/status") { [self] request, context in
            await handleActivityStatus(request, context: context)
        }

        // Hook event logging endpoint
        router.post("/api/v1/agent/hook-event") { [self] request, context in
            await handleHookEvent(request, context: context)
        }

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname("127.0.0.1", port: port)
            )
        )

        self.app = app

        logger.info("[skwad] Starting MCP server on port \(port)")

        serverTask = Task {
            try await app.run()
        }
    }

    func stop() async {
        logger.info("[skwad] Stopping MCP server")
        serverTask?.cancel()
        serverTask = nil
        app = nil
    }

    // MARK: - Request Handlers

    private func handleMCPRequest(_ request: Request, context: BasicRequestContext) async -> Response {
        // Get session ID from header
        let sessionId = request.headers[.init("Mcp-Session-Id")!]

        // Check if client wants SSE streaming
        let acceptsSSE = request.headers[.accept]?.contains("text/event-stream") ?? false

        // Parse JSON-RPC request
        do {
            let bodyBuffer = try await request.body.collect(upTo: 1024 * 1024)
            let bodyData = Data(buffer: bodyBuffer)

            guard let jsonRequest = try? JSONDecoder().decode(JSONRPCRequest.self, from: bodyData) else {
                return errorResponse(code: -32700, message: "Parse error: invalid JSON")
            }

            logger.debug("Received MCP request: \(jsonRequest.method)")

            // Per MCP spec: notifications (no id) must return 202 Accepted with no body
            if jsonRequest.method.starts(with: "notifications/") {
                return Response(status: .accepted)
            }

            // Handle the request
            let response = await handleJSONRPCRequest(jsonRequest, sessionId: sessionId)

            // Encode response
            guard let responseData = try? JSONEncoder().encode(response) else {
                return errorResponse(code: -32603, message: "Internal error: could not encode response")
            }

            // Generate session ID for initialize responses
            let responseSessionId: String
            if jsonRequest.method == MCPMethod.initialize.rawValue {
                responseSessionId = UUID().uuidString
            } else {
                responseSessionId = sessionId ?? UUID().uuidString
            }

            // Return as SSE if requested
            if acceptsSSE {
                let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
                let event = SSEEvent(event: "message", data: responseString, id: nil)

                var headers = HTTPFields()
                headers[.contentType] = "text/event-stream"
                headers[.cacheControl] = "no-cache"
                headers[.init("Connection")!] = "keep-alive"
                headers[.init("Mcp-Session-Id")!] = responseSessionId

                return Response(
                    status: .ok,
                    headers: headers,
                    body: .init(byteBuffer: .init(string: event.formatted()))
                )
            }

            // Return as JSON by default
            var headers = HTTPFields()
            headers[.contentType] = "application/json"
            headers[.init("Mcp-Session-Id")!] = responseSessionId

            return Response(
                status: .ok,
                headers: headers,
                body: .init(byteBuffer: .init(data: responseData))
            )
        } catch {
            return errorResponse(code: -32700, message: "Parse error: \(error.localizedDescription)")
        }
    }

    private func handleSSERequest(_ request: Request, context: BasicRequestContext) async -> Response {
        // SSE endpoint for server-initiated messages
        // For now, return a simple acknowledgment
        // Full SSE implementation would require async streaming
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        headers[.init("Connection")!] = "keep-alive"

        let event = SSEEvent(event: "connected", data: "{\"status\":\"connected\"}", id: nil)

        return Response(
            status: .ok,
            headers: headers,
            body: .init(byteBuffer: .init(string: event.formatted()))
        )
    }

    // MARK: - Debug Status

    private func handleStatus(_ request: Request, context: BasicRequestContext) async -> Response {
        let agents = await mcpService.getAllAgents()
        let entries = agents.map { agent -> [String: Any] in
            var entry: [String: Any] = [
                "agent_id": agent.id.uuidString,
                "name": agent.name,
                "folder": agent.folder,
                "status": agent.status.rawValue,
                "registered": agent.isRegistered,
                "agent_type": agent.agentType,
            ]
            if let sessionId = agent.sessionId {
                entry["session_id"] = sessionId
            }
            return entry
        }
        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else {
            return plainResponse(status: .internalServerError, body: "Failed to serialize")
        }
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: .init(data: data)))
    }

    // MARK: - Activity Status Handler

    private func handleHookRegister(_ request: Request, context: BasicRequestContext) async -> Response {
        do {
            let bodyBuffer = try await request.body.collect(upTo: 64 * 1024)
            let bodyData = Data(buffer: bodyBuffer)

            guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  let agentIdString = json["agent_id"] as? String,
                  let agentId = UUID(uuidString: agentIdString) else {
                return plainResponse(status: .badRequest, body: "Missing or invalid agent_id")
            }

            let sessionId = json["session_id"] as? String
            let success = await mcpService.registerAgent(agentId: agentIdString, sessionId: sessionId)
            if success {
                logger.info("[skwad][\(String(agentId.uuidString.prefix(8)).lowercased())] Hook registration successful")

                // Return skwad members as JSON
                let members = await mcpService.listAgents(callerAgentId: agentIdString)
                let response = RegisterAgentResponse(
                    success: true,
                    message: "Registered",
                    unreadMessageCount: 0,
                    skwadMembers: members
                )
                if let data = try? JSONEncoder().encode(response) {
                    var headers = HTTPFields()
                    headers[.contentType] = "application/json"
                    return Response(status: .ok, headers: headers, body: .init(byteBuffer: .init(data: data)))
                }
                return plainResponse(status: .ok, body: "OK")
            } else {
                return plainResponse(status: .notFound, body: "Agent not found")
            }
        } catch {
            return plainResponse(status: .badRequest, body: "Failed to read body")
        }
    }

    private func handleActivityStatus(_ request: Request, context: BasicRequestContext) async -> Response {
        do {
            let bodyBuffer = try await request.body.collect(upTo: 64 * 1024)
            let bodyData = Data(buffer: bodyBuffer)

            guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  let agentIdString = json["agent_id"] as? String,
                  let agentId = UUID(uuidString: agentIdString) else {
                return plainResponse(status: .badRequest, body: "Missing or invalid agent_id")
            }
            guard let statusString = json["status"] as? String,
                  let agentStatus = (statusString == "running" ? AgentStatus.running : statusString == "idle" ? AgentStatus.idle : nil) else {
                return plainResponse(status: .badRequest, body: "Invalid status (expected: running or idle)")
            }

            await mcpService.updateAgentStatus(for: agentId, status: agentStatus, source: .hook)
            logger.info("[skwad][\(String(agentId.uuidString.prefix(8)).lowercased())] Hook status: \(statusString)")

            return plainResponse(status: .ok, body: "OK")
        } catch {
            return plainResponse(status: .badRequest, body: "Failed to read body")
        }
    }

    // MARK: - Hook Event Handler

    private func handleHookEvent(_ request: Request, context: BasicRequestContext) async -> Response {
        do {
            let bodyBuffer = try await request.body.collect(upTo: 64 * 1024)
            let bodyData = Data(buffer: bodyBuffer)

            guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
                  let agentIdString = json["agent_id"] as? String,
                  let agentId = UUID(uuidString: agentIdString),
                  let hookType = json["hook_type"] as? String else {
                return plainResponse(status: .badRequest, body: "Invalid hook event payload")
            }

            let payload = json["payload"] as? [String: Any]
            let notificationType = payload?["notification_type"] as? String

            let agentPrefix = "[skwad][\(String(agentId.uuidString.prefix(8)).lowercased())]"
            logger.info("\(agentPrefix) Hook event: \(hookType) (notification_type=\(notificationType ?? "none"))")

            // Notification hook with permission_prompt → blocked status + desktop notification
            // notifyBlocked is called BEFORE updateAgentStatus so that the dedup check
            // (which skips if agent is already .blocked) sees the pre-update status.
            if (hookType.lowercased() == "permission_request" || (hookType.lowercased() == "notification" && notificationType?.lowercased() == "permission_prompt")) {
                let message = payload?["message"] as? String
                let agent = await mcpService.findAgentById(agentId)
                if let agent = agent {
                    await MainActor.run {
                        NotificationService.shared.notifyBlocked(agent: agent, message: message)
                    }
                }
                await mcpService.updateAgentStatus(for: agentId, status: .blocked, source: .hook)
            }

            return plainResponse(status: .ok, body: "OK")
        } catch {
            return plainResponse(status: .badRequest, body: "Failed to read body")
        }
    }

    private func plainResponse(status: HTTPResponse.Status, body: String) -> Response {
        Response(status: status, body: .init(byteBuffer: .init(string: body)))
    }

    // MARK: - JSON-RPC Handler

    private func handleJSONRPCRequest(_ request: JSONRPCRequest, sessionId: String?) async -> JSONRPCResponse {
        switch request.method {
        case MCPMethod.initialize.rawValue:
            return handleInitialize(request)

        case MCPMethod.listTools.rawValue:
            return await handleListTools(request)

        case MCPMethod.callTool.rawValue:
            return await handleCallTool(request)

        case MCPMethod.shutdown.rawValue:
            return JSONRPCResponse.success(id: request.id, result: EmptyResult())

        default:
            return JSONRPCResponse.error(id: request.id, code: -32601, message: "Method not found: \(request.method)")
        }
    }

    // MARK: - MCP Protocol Handlers

    private func handleInitialize(_ request: JSONRPCRequest) -> JSONRPCResponse {
        let result = InitializeResult(
            protocolVersion: "2024-11-05",
            capabilities: ServerCapabilities(tools: ToolsCapability(listChanged: false)),
            serverInfo: ServerInfo(name: "skwad-mcp", version: "1.0.0")
        )
        return JSONRPCResponse.success(id: request.id, result: result)
    }

    private func handleListTools(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        let tools = await toolHandler.listTools()
        let result = ListToolsResult(tools: tools)
        return JSONRPCResponse.success(id: request.id, result: result)
    }

    private func handleCallTool(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let params = request.params,
              let name = params["name"]?.stringValue else {
            return JSONRPCResponse.error(id: request.id, code: -32602, message: "Invalid params: missing tool name")
        }

        let arguments = params["arguments"]?.dictionaryValue ?? [:]
        let result = await toolHandler.callTool(name: name, arguments: arguments)
        return JSONRPCResponse.success(id: request.id, result: result)
    }

    // MARK: - Helpers

    private func errorResponse(code: Int, message: String) -> Response {
        let response = JSONRPCResponse.error(id: nil, code: code, message: message)
        let data = (try? JSONEncoder().encode(response)) ?? Data()

        var headers = HTTPFields()
        headers[.contentType] = "application/json"

        return Response(
            status: .badRequest,
            headers: headers,
            body: .init(byteBuffer: .init(data: data))
        )
    }
}

// MARK: - MCP Protocol Types

private struct InitializeResult: Codable {
    let protocolVersion: String
    let capabilities: ServerCapabilities
    let serverInfo: ServerInfo
}

private struct ServerCapabilities: Codable {
    let tools: ToolsCapability
}

private struct ToolsCapability: Codable {
    let listChanged: Bool
}

private struct ServerInfo: Codable {
    let name: String
    let version: String
}

private struct ListToolsResult: Codable {
    let tools: [ToolDefinition]
}

private struct EmptyResult: Codable {}
