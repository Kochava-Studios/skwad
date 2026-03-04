import Foundation

/// Shared model for a conversation session summary
struct SessionSummary: Identifiable {
    let id: String          // session UUID (filename without extension)
    let title: String       // first meaningful user message
    let timestamp: Date     // file modification date
    let messageCount: Int   // number of user+assistant messages
}

/// Protocol for agent-specific conversation history parsing
protocol ConversationHistoryProvider {
    /// Load sessions for a given project folder (up to 20, sorted by date descending)
    func loadSessions(for folder: String) -> [SessionSummary]
    /// Delete a session and its associated files
    func deleteSession(id: String, folder: String)
}

@Observable @MainActor
class ConversationHistoryService {
    static let shared = ConversationHistoryService()

    private var cache: [String: [SessionSummary]] = [:]
    private(set) var isLoading = false

    private let providers: [String: ConversationHistoryProvider] = [
        "claude": ClaudeHistoryProvider(),
        "codex": CodexHistoryProvider(),
        "gemini": GeminiHistoryProvider(),
        "copilot": CopilotHistoryProvider(),
    ]

    private init() {}

    /// Whether conversation history is available for a given agent type
    func supportsHistory(agentType: String) -> Bool {
        providers[agentType] != nil
    }

    /// Get cached sessions for a folder/agent type combo
    func sessions(for folder: String, agentType: String) -> [SessionSummary] {
        let key = cacheKey(folder: folder, agentType: agentType)
        return cache[key] ?? []
    }

    /// Refresh sessions for a folder/agent type combo
    func refresh(for folder: String, agentType: String) async {
        guard let provider = providers[agentType] else { return }

        isLoading = true
        let p = provider
        let f = folder

        let summaries = await Task.detached(priority: .utility) {
            p.loadSessions(for: f)
        }.value

        let key = cacheKey(folder: folder, agentType: agentType)
        cache[key] = summaries
        isLoading = false
    }

    /// Delete a session, then re-read to backfill
    func deleteSession(id: String, folder: String, agentType: String) async {
        guard let provider = providers[agentType] else { return }

        provider.deleteSession(id: id, folder: folder)

        await refresh(for: folder, agentType: agentType)
    }

    /// Invalidate cache for a folder
    func invalidate(for folder: String, agentType: String) {
        let key = cacheKey(folder: folder, agentType: agentType)
        cache.removeValue(forKey: key)
    }

    private func cacheKey(folder: String, agentType: String) -> String {
        "\(agentType):\(folder)"
    }
}
