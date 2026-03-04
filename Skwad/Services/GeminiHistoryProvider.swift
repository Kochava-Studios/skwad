import Foundation

struct GeminiHistoryProvider: ConversationHistoryProvider {

    private static let basePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.gemini/tmp"
    }()

    func loadSessions(for folder: String) -> [SessionSummary] {
        guard let projectDir = findProjectDirectory(for: folder) else { return [] }

        let logsPath = (projectDir as NSString).appendingPathComponent("logs.json")
        guard let data = FileManager.default.contents(atPath: logsPath),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        // Group by sessionId, keep the first user message per session
        var sessionMap: [String: (message: String, timestamp: Date)] = [:]
        for entry in entries {
            guard let sessionId = entry["sessionId"] as? String,
                  let type = entry["type"] as? String, type == "user",
                  let message = entry["message"] as? String,
                  let timestampStr = entry["timestamp"] as? String else {
                continue
            }
            // Only keep the first entry per session
            if sessionMap[sessionId] == nil {
                let timestamp = parseISO8601(timestampStr) ?? Date.distantPast
                sessionMap[sessionId] = (message: message, timestamp: timestamp)
            }
        }

        // Sort by timestamp descending, limit to 20
        let sorted = sessionMap.sorted { $0.value.timestamp > $1.value.timestamp }
        let limited = sorted.prefix(20)

        let chatsDir = (projectDir as NSString).appendingPathComponent("chats")

        return limited.map { (sessionId, info) in
            let title = resolveTitle(info.message, sessionId: sessionId, chatsDir: chatsDir)
            return SessionSummary(id: sessionId, title: title, timestamp: info.timestamp, messageCount: 0)
        }
    }

    func deleteSession(id: String, folder: String) {
        guard let projectDir = findProjectDirectory(for: folder) else { return }

        // Delete matching chat file
        let chatsDir = (projectDir as NSString).appendingPathComponent("chats")
        if let chatFile = findChatFile(sessionId: id, in: chatsDir) {
            try? FileManager.default.removeItem(atPath: chatFile)
        }

        // Remove entry from logs.json
        let logsPath = (projectDir as NSString).appendingPathComponent("logs.json")
        guard let data = FileManager.default.contents(atPath: logsPath),
              var entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        entries.removeAll { ($0["sessionId"] as? String) == id }
        if let updated = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted]) {
            try? updated.write(to: URL(fileURLWithPath: logsPath))
        }
    }

    // MARK: - Project Directory Discovery

    /// Find the ~/.gemini/tmp/<name>/ folder whose .project_root matches the given folder
    func findProjectDirectory(for folder: String) -> String? {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: Self.basePath) else { return nil }

        for dir in dirs {
            let fullPath = (Self.basePath as NSString).appendingPathComponent(dir)
            let projectRootFile = (fullPath as NSString).appendingPathComponent(".project_root")
            guard let rootData = fm.contents(atPath: projectRootFile),
                  let root = String(data: rootData, encoding: .utf8) else {
                continue
            }
            if root.trimmingCharacters(in: .whitespacesAndNewlines) == folder {
                return fullPath
            }
        }
        return nil
    }

    // MARK: - Title Resolution

    private func resolveTitle(_ logMessage: String, sessionId: String, chatsDir: String) -> String {
        if !isRegistrationPrompt(logMessage) {
            return truncateTitle(logMessage)
        }

        // Fall back to parsing the chat JSON for the first real user message
        if let chatFile = findChatFile(sessionId: sessionId, in: chatsDir) {
            if let title = titleFromChatFile(path: chatFile) {
                return title
            }
        }

        return ""
    }

    private func isRegistrationPrompt(_ text: String) -> Bool {
        let lc = text.lowercased()
        return lc.contains("you are part of a team of agents")
            || lc.contains("register with the skwad")
            || lc.contains("list other agents names and project")
    }

    /// Parse a Gemini chat JSON file to find the first real user message
    func titleFromChatFile(path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return nil
        }

        for msg in messages {
            guard let type = msg["type"] as? String, type == "user",
                  let content = msg["content"] as? [[String: Any]],
                  let text = content.first?["text"] as? String else {
                continue
            }

            if isRegistrationPrompt(text) { continue }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            return truncateTitle(trimmed)
        }

        return nil
    }

    /// Find the chat file for a session ID in the chats directory
    /// Files are named like: session-2026-03-04T01-08-8ed8bc14.json (short prefix of session ID)
    private func findChatFile(sessionId: String, in chatsDir: String) -> String? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: chatsDir) else { return nil }

        // The filename contains a short prefix of the session ID (first 8 chars)
        let shortId = String(sessionId.prefix(8))
        for file in files where file.hasSuffix(".json") && file.contains(shortId) {
            return (chatsDir as NSString).appendingPathComponent(file)
        }
        return nil
    }

    private func truncateTitle(_ text: String) -> String {
        let firstLine = text.components(separatedBy: "\n").first ?? text
        if firstLine.count > 80 {
            return String(firstLine.prefix(77)) + "..."
        }
        return firstLine
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
