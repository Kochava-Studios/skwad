import Foundation
import Logging

/// Handles hook events specific to Claude agents.
/// Business logic only — HTTP concerns (request parsing, response building) stay in MCPServer.
struct ClaudeHookHandler {
    let mcpService: AgentCoordinator
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

        // Stop hook + autopilot enabled → classify last assistant message
        let hook = json["hook"] as? String
        if hook == "Stop",
           AppSettings.shared.autopilotEnabled,
           !AppSettings.shared.aiApiKey.isEmpty {
            let payload = json["payload"] as? [String: Any]
            let transcriptPath = payload?["transcript_path"] as? String

            // Parse transcript: returns nil if unreadable, empty string for registration responses
            let lastMessage = Self.lastAssistantMessageFromTranscript(path: transcriptPath)
            if let lastMessage = lastMessage, !lastMessage.isEmpty {
                let agent = await mcpService.findAgentById(agentId)
                let agentName = agent?.name ?? "Unknown"
                Task {
                    await AutopilotService.shared.analyze(
                        lastMessage: lastMessage,
                        agentId: agentId,
                        agentName: agentName
                    )
                }
            }
        }

        await mcpService.updateAgentStatus(for: agentId, status: agentStatus, source: .hook)
        return agentStatus
    }

    // MARK: - Transcript Parsing

    /// Extract the last assistant message from a Claude transcript JSONL file.
    /// Returns `nil` if the file can't be read or has no assistant message.
    /// Returns empty string if the assistant message is a response to our registration prompt (caller should skip).
    static func lastAssistantMessageFromTranscript(path: String?) -> String? {
        guard let path = path else { return nil }
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines)
        var assistantText: String?

        // Parse backwards: find the last assistant message, then check the preceding user message
        for line in lines.reversed() {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            if assistantText == nil {
                // Looking for the last assistant message
                guard type == "assistant",
                      let message = json["message"] as? [String: Any] else {
                    continue
                }
                assistantText = extractText(from: message)
                if assistantText?.isEmpty ?? true { assistantText = nil; continue }
                continue
            }

            // Found assistant, now check the preceding user message
            if type == "user" {
                guard let message = json["message"] as? [String: Any] else { break }
                let userText = extractText(from: message)
                if userText == TerminalCommandBuilder.registrationUserPrompt {
                    return ""
                }
                break
            }
        }

        return assistantText
    }

    /// Extract text from a message's content (supports both plain string and array-of-parts formats).
    private static func extractText(from message: [String: Any]) -> String? {
        if let plain = message["content"] as? String {
            let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text" else { return nil }
                return part["text"] as? String
            }.joined(separator: "\n")
            return text.isEmpty ? nil : text
        }
        return nil
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
