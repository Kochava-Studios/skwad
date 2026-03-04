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
    /// Returns the directory where this agent stores sessions for a given project folder
    func sessionsDirectory(for folder: String) -> String
    /// Parse all sessions in a directory, returning up to `maxSessions` summaries sorted by date descending
    func parseSessions(in directory: String) -> [SessionSummary]
    /// Parse a single session file into a summary, or nil if it has no valid content
    func parseSessionFile(path: String, sessionId: String, timestamp: Date) -> SessionSummary?
    /// Delete all files associated with a session (transcript, data directory, etc.)
    func deleteSessionFiles(id: String, in directory: String)
}

/// Default implementation for common session discovery logic
extension ConversationHistoryProvider {
    func parseSessions(in directory: String) -> [SessionSummary] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        let fileExtension = sessionFileExtension
        var sessionFiles: [(name: String, date: Date)] = []
        for file in contents where file.hasSuffix(fileExtension) {
            let path = (directory as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date {
                sessionFiles.append((name: file, date: modDate))
            }
        }
        sessionFiles.sort { $0.date > $1.date }

        let maxSessions = 20
        var summaries: [SessionSummary] = []
        for (index, file) in sessionFiles.enumerated() {
            let sessionId = String(file.name.dropLast(fileExtension.count))
            let path = (directory as NSString).appendingPathComponent(file.name)

            if let summary = parseSessionFile(path: path, sessionId: sessionId, timestamp: file.date) {
                summaries.append(summary)
            } else if index == 0 {
                summaries.append(SessionSummary(id: sessionId, title: "", timestamp: file.date, messageCount: 0))
            }
            if summaries.count >= maxSessions { break }
        }

        return summaries
    }

    /// File extension used for session files (including the dot). Override if different from `.jsonl`.
    var sessionFileExtension: String { ".jsonl" }
}

@Observable @MainActor
class ConversationHistoryService {
    static let shared = ConversationHistoryService()

    private var cache: [String: [SessionSummary]] = [:]
    private(set) var isLoading = false

    private let providers: [String: ConversationHistoryProvider] = [
        "claude": ClaudeHistoryProvider(),
    ]

    private init() {}

    /// Get cached sessions for a folder/agent type combo
    func sessions(for folder: String, agentType: String) -> [SessionSummary] {
        let key = cacheKey(folder: folder, agentType: agentType)
        return cache[key] ?? []
    }

    /// Refresh sessions for a folder/agent type combo
    func refresh(for folder: String, agentType: String) async {
        guard let provider = providers[agentType] else { return }

        let directory = provider.sessionsDirectory(for: folder)
        guard FileManager.default.fileExists(atPath: directory) else {
            let key = cacheKey(folder: folder, agentType: agentType)
            cache[key] = []
            return
        }

        isLoading = true
        let p = provider

        let summaries = await Task.detached(priority: .utility) {
            p.parseSessions(in: directory)
        }.value

        let key = cacheKey(folder: folder, agentType: agentType)
        cache[key] = summaries
        isLoading = false
    }

    /// Delete a session's files, then re-read to backfill
    func deleteSession(id: String, folder: String, agentType: String) async {
        guard let provider = providers[agentType] else { return }

        let directory = provider.sessionsDirectory(for: folder)
        provider.deleteSessionFiles(id: id, in: directory)

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
