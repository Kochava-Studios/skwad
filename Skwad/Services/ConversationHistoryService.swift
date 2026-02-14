import Foundation

@Observable @MainActor
class ConversationHistoryService {
    static let shared = ConversationHistoryService()

    struct SessionSummary: Identifiable {
        let id: String          // session UUID (filename without .jsonl)
        let title: String       // first meaningful user message
        let timestamp: Date     // file modification date
        let messageCount: Int   // number of user+assistant messages
    }

    private var cache: [String: [SessionSummary]] = [:]
    private(set) var isLoading = false

    private init() {}

    /// Get cached sessions for a folder/agent type combo
    func sessions(for folder: String, agentType: String) -> [SessionSummary] {
        let key = cacheKey(folder: folder, agentType: agentType)
        return cache[key] ?? []
    }

    /// Refresh sessions for a folder/agent type combo
    func refresh(for folder: String, agentType: String) async {
        guard agentType == "claude" else { return }

        let projectDir = claudeProjectsPath(for: folder)
        guard FileManager.default.fileExists(atPath: projectDir) else {
            let key = cacheKey(folder: folder, agentType: agentType)
            cache[key] = []
            return
        }

        isLoading = true
        let dir = projectDir

        let summaries = await Task.detached(priority: .utility) {
            Self.parseSessions(in: dir)
        }.value

        let key = cacheKey(folder: folder, agentType: agentType)
        cache[key] = summaries
        isLoading = false
    }

    /// Delete a session's JSONL file and data directory, then re-read to backfill
    func deleteSession(id: String, folder: String, agentType: String) async {
        let projectDir = claudeProjectsPath(for: folder)
        let fm = FileManager.default

        // Delete .jsonl file
        let jsonlPath = (projectDir as NSString).appendingPathComponent("\(id).jsonl")
        try? fm.removeItem(atPath: jsonlPath)

        // Delete data directory (subagents, etc.)
        let dataPath = (projectDir as NSString).appendingPathComponent(id)
        try? fm.removeItem(atPath: dataPath)

        // Re-read to backfill the list to 20
        await refresh(for: folder, agentType: agentType)
    }

    /// Invalidate cache for a folder
    func invalidate(for folder: String, agentType: String) {
        let key = cacheKey(folder: folder, agentType: agentType)
        cache.removeValue(forKey: key)
    }

    // MARK: - Path Derivation

    /// Derive the Claude projects path for a given folder
    /// e.g. /Users/foo/src/bar → ~/.claude/projects/-Users-foo-src-bar
    private func claudeProjectsPath(for folder: String) -> String {
        let dashPath = folder.replacingOccurrences(of: "/", with: "-")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects/\(dashPath)"
    }

    private func cacheKey(folder: String, agentType: String) -> String {
        "\(agentType):\(folder)"
    }

    // MARK: - JSONL Parsing (runs on background thread)

    private nonisolated static func parseSessions(in directory: String) -> [SessionSummary] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory) else { return [] }

        // Filter to .jsonl files and sort by modification date descending
        var jsonlFiles: [(name: String, date: Date)] = []
        for file in contents where file.hasSuffix(".jsonl") {
            let path = (directory as NSString).appendingPathComponent(file)
            if let attrs = try? fm.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date {
                jsonlFiles.append((name: file, date: modDate))
            }
        }
        jsonlFiles.sort { $0.date > $1.date }

        // Parse files until we have 20 valid sessions
        let maxSessions = 20
        var summaries: [SessionSummary] = []
        for file in jsonlFiles {
            let sessionId = String(file.name.dropLast(6)) // remove .jsonl
            let path = (directory as NSString).appendingPathComponent(file.name)

            guard let summary = parseJSONLFile(path: path, sessionId: sessionId, timestamp: file.date) else {
                continue
            }
            summaries.append(summary)
            if summaries.count >= maxSessions { break }
        }

        return summaries
    }

    private nonisolated static func parseJSONLFile(path: String, sessionId: String, timestamp: Date) -> SessionSummary? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: "\n")
        var title: String?
        var messageCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            // Count user + assistant messages
            if type == "user" || type == "assistant" {
                messageCount += 1
            }

            // Extract title from first meaningful user message
            if title == nil && type == "user" {
                // Skip meta messages
                if json["isMeta"] as? Bool == true { continue }

                // Get content string
                guard let message = json["message"] as? [String: Any],
                      let messageContent = message["content"] as? String else {
                    continue
                }

                // Skip Skwad registration prompts (various phrasings over time)
                let lc = messageContent.lowercased()
                if lc.contains("you are part of a team of agents") { continue }
                if lc.contains("register with the skwad") { continue }
                if lc.contains("list other agents names and project") { continue }

                // Skip command/meta messages
                if messageContent.contains("<command-name>") { continue }
                if messageContent.contains("<local-command-") { continue }

                // Skip empty or whitespace-only
                let cleaned = messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty { continue }

                // Use first line, truncated to 80 chars
                let firstLine = cleaned.components(separatedBy: "\n").first ?? cleaned
                if firstLine.count > 80 {
                    title = String(firstLine.prefix(77)) + "..."
                } else {
                    title = firstLine
                }
            }
        }

        // Skip files with no valid user messages or no messages at all
        guard let title = title, messageCount > 0 else { return nil }

        return SessionSummary(
            id: sessionId,
            title: title,
            timestamp: timestamp,
            messageCount: messageCount
        )
    }
}
