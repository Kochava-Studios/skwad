import Foundation
import Logging

/// Handles hook events specific to Codex agents.
/// Codex fires a single `notify` event (agent-turn-complete) with the last assistant message
/// directly in the payload — no transcript parsing needed.
struct CodexHookHandler {
    let mcpService: AgentCoordinator
    let logger: Logger

    // MARK: - Activity Status

    /// Handle Codex notify events (agent-turn-complete).
    /// Returns the parsed AgentStatus or nil on error.
    func handleActivityStatus(agentId: UUID, json: [String: Any]) async -> AgentStatus? {
        let payload = json["payload"] as? [String: Any]
        let eventType = payload?["type"] as? String

        guard eventType == "agent-turn-complete" else {
            return nil
        }

        let metadata = extractMetadata(from: payload)
        if !metadata.isEmpty {
            await mcpService.updateMetadata(for: agentId, metadata: metadata)
        }

        // Autopilot: Codex gives us last-assistant-message directly (no transcript needed)
        if AppSettings.shared.autopilotEnabled,
           !AppSettings.shared.aiApiKey.isEmpty {
            let lastMessage = payload?["last-assistant-message"] as? String
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

        await mcpService.updateAgentStatus(for: agentId, status: .idle, source: .hook)
        return .idle
    }

    // MARK: - Metadata Extraction

    /// Extract known metadata fields from a Codex notify payload.
    func extractMetadata(from payload: [String: Any]?) -> [String: String] {
        guard let payload = payload else { return [:] }
        let knownKeys = ["cwd", "thread-id", "turn-id"]
        var metadata: [String: String] = [:]
        for key in knownKeys {
            if let value = payload[key] as? String, !value.isEmpty {
                metadata[key] = value
            }
        }
        return metadata
    }
}
