import Foundation

struct ClaudeHistoryProvider: ConversationHistoryProvider {

    func sessionsDirectory(for folder: String) -> String {
        let dashPath = folder.replacingOccurrences(of: "/", with: "-")
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/projects/\(dashPath)"
    }

    func deleteSessionFiles(id: String, in directory: String) {
        let fm = FileManager.default
        let jsonlPath = (directory as NSString).appendingPathComponent("\(id).jsonl")
        try? fm.removeItem(atPath: jsonlPath)
        let dataPath = (directory as NSString).appendingPathComponent(id)
        try? fm.removeItem(atPath: dataPath)
    }

    func parseSessionFile(path: String, sessionId: String, timestamp: Date) -> SessionSummary? {
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

            if type == "user" || type == "assistant" {
                messageCount += 1
            }

            if title == nil && type == "user" {
                if json["isMeta"] as? Bool == true { continue }

                guard let message = json["message"] as? [String: Any],
                      let messageContent = message["content"] as? String else {
                    continue
                }

                let lc = messageContent.lowercased()
                if lc.contains("you are part of a team of agents") { continue }
                if lc.contains("register with the skwad") { continue }
                if lc.contains("list other agents names and project") { continue }

                if messageContent.contains("<local-command-") { continue }

                let cleaned: String
                if messageContent.contains("<command-name>") {
                    cleaned = Self.formatCommandMessage(messageContent)
                    if cleaned.isEmpty { continue }
                } else {
                    let trimmedContent = messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedContent.isEmpty { continue }
                    cleaned = trimmedContent
                }

                let firstLine = cleaned.components(separatedBy: "\n").first ?? cleaned
                if firstLine.count > 80 {
                    title = String(firstLine.prefix(77)) + "..."
                } else {
                    title = firstLine
                }
            }
        }

        guard let title = title, messageCount > 0 else { return nil }

        return SessionSummary(
            id: sessionId,
            title: title,
            timestamp: timestamp,
            messageCount: messageCount
        )
    }

    /// Format a command message like "<command-name>/review</command-name>...<command-args>text</command-args>"
    /// into "/review text"
    static func formatCommandMessage(_ content: String) -> String {
        guard let nameStart = content.range(of: "<command-name>"),
              let nameEnd = content.range(of: "</command-name>") else {
            return ""
        }
        let commandName = String(content[nameStart.upperBound..<nameEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var args = ""
        if let argsStart = content.range(of: "<command-args>"),
           let argsEnd = content.range(of: "</command-args>") {
            args = String(content[argsStart.upperBound..<argsEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if args.isEmpty {
            return commandName
        }
        return "\(commandName) \(args)"
    }
}
