import Foundation
import Logging

/// Handles hook events specific to Claude agents.
/// Business logic only — HTTP concerns (request parsing, response building) stay in MCPServer.
struct ClaudeHookHandler {
    let mcpService: MCPService
    let logger: Logger

    // MARK: - Hook Registration

    /// Handle hook-based registration (SessionStart).
    /// Called for both `source=startup` (new session) and `source=resume` (resumed session).
    /// - startup: full registration with session ID
    /// - resume: only update session ID if agent is resuming (not forking)
    /// Returns true on success so MCPServer can build the HTTP response.
    func handleRegister(agentId: UUID, agentIdString: String, json: [String: Any]) async -> Bool {
        let sessionId = json["session_id"] as? String
        let source = json["source"] as? String ?? "startup"

        let metadata = extractMetadata(from: json["payload"] as? [String: Any])
        if !metadata.isEmpty {
            await mcpService.updateMetadata(for: agentId, metadata: metadata)
        }

        let agentPrefix = "[skwad][\(String(agentId.uuidString.prefix(8)).lowercased())]"
        let agent = await mcpService.findAgentById(agentId)

        if source == "resume" {
            // Resume event always sets session ID (this is the session Claude is actually using)
            // Exception: fork — the new startup session is the active one
            logger.info("\(agentPrefix) Register source=\(source) payload_session=\(sessionId ?? "nil") agent_session=\(agent?.sessionId ?? "nil") fork=\(agent?.forkSession ?? false)")
            if let agent = agent, !agent.forkSession, let sessionId = sessionId {
                await mcpService.setSessionId(for: agentId, sessionId: sessionId)
            }
            return true
        }

        // Startup event: register the agent
        // Only set session ID if this is a scratch start or a fork
        // (pure resume will get its session ID from the resume event)
        let isResuming = agent?.resumeSessionId != nil && !(agent?.forkSession ?? false)
        logger.info("\(agentPrefix) Register source=\(source) payload_session=\(sessionId ?? "nil") agent_session=\(agent?.sessionId ?? "nil") isResuming=\(isResuming)")
        return await mcpService.registerAgent(agentId: agentIdString, sessionId: isResuming ? nil : sessionId)
    }

    // MARK: - Activity Status

    /// Handle activity status updates (UserPromptSubmit / Stop / PreToolUse hooks).
    /// Returns the parsed AgentStatus or nil on error.
    func handleActivityStatus(agentId: UUID, json: [String: Any]) async -> AgentStatus? {
        guard let statusString = json["status"] as? String,
              let agentStatus = (statusString == "running" ? AgentStatus.running :
                                 statusString == "idle" ? AgentStatus.idle :
                                 statusString == "input" ? AgentStatus.input : nil) else {
            return nil
        }

        let metadata = extractMetadata(from: json["payload"] as? [String: Any])
        if !metadata.isEmpty {
            await mcpService.updateMetadata(for: agentId, metadata: metadata)
        }

        // Input status → desktop notification (with message from payload if available)
        if agentStatus == .input {
            let payload = json["payload"] as? [String: Any]
            let message = payload?["message"] as? String
            let agent = await mcpService.findAgentById(agentId)
            if let agent = agent {
                await MainActor.run {
                    NotificationService.shared.notifyAwaitingInput(agent: agent, message: message)
                }
            }
        }

        await mcpService.updateAgentStatus(for: agentId, status: agentStatus, source: .hook)
        return agentStatus
    }

    // MARK: - Metadata Extraction

    /// Extract known metadata fields from a raw hook payload.
    /// Only includes fields that are present and non-empty strings.
    func extractMetadata(from payload: [String: Any]?) -> [String: String] {
        guard let payload = payload else { return [:] }
        let knownKeys = ["transcript_path", "cwd", "model", "session_id"]
        var metadata: [String: String] = [:]
        for key in knownKeys {
            if let value = payload[key] as? String, !value.isEmpty {
                metadata[key] = value
            }
        }
        return metadata
    }
}
