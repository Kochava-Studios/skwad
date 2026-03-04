import Foundation

struct CopilotHistoryProvider: ConversationHistoryProvider {

    private static let basePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.copilot/session-state"
    }()

    func loadSessions(for folder: String) -> [SessionSummary] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: Self.basePath) else { return [] }

        var summaries: [SessionSummary] = []

        for entry in entries {
            let sessionDir = (Self.basePath as NSString).appendingPathComponent(entry)
            let workspacePath = (sessionDir as NSString).appendingPathComponent("workspace.yaml")

            guard let yaml = parseWorkspaceYaml(path: workspacePath) else { continue }
            guard yaml.cwd == folder else { continue }

            let title = resolveTitle(yaml.summary, sessionDir: sessionDir)
            summaries.append(SessionSummary(
                id: entry,
                title: title,
                timestamp: yaml.updatedAt,
                messageCount: 0
            ))
        }

        summaries.sort { $0.timestamp > $1.timestamp }
        return Array(summaries.prefix(20))
    }

    func deleteSession(id: String, folder: String) {
        let sessionDir = (Self.basePath as NSString).appendingPathComponent(id)
        try? FileManager.default.removeItem(atPath: sessionDir)
    }

    // MARK: - Workspace YAML Parsing

    struct WorkspaceInfo {
        let cwd: String
        let summary: String
        let updatedAt: Date
    }

    /// Simple line-based YAML parser for workspace.yaml (flat key: value format)
    func parseWorkspaceYaml(path: String) -> WorkspaceInfo? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var fields: [String: String] = [:]
        for line in content.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            fields[key] = value
        }

        guard let cwd = fields["cwd"] else { return nil }
        let summary = fields["summary"] ?? ""
        let updatedAt = fields["updated_at"].flatMap { parseISO8601($0) } ?? Date.distantPast

        return WorkspaceInfo(cwd: cwd, summary: summary, updatedAt: updatedAt)
    }

    // MARK: - Title Resolution

    private func resolveTitle(_ summary: String, sessionDir: String) -> String {
        if !summary.isEmpty && !isRegistrationPrompt(summary) {
            return truncateTitle(summary)
        }

        // Fall back to parsing events.jsonl for first real user message
        let eventsPath = (sessionDir as NSString).appendingPathComponent("events.jsonl")
        return titleFromEvents(path: eventsPath) ?? ""
    }

    private func isRegistrationPrompt(_ text: String) -> Bool {
        let lc = text.lowercased()
        return lc.contains("you are part of a team of agents")
            || lc.contains("register with the skwad")
            || lc.contains("list other agents names and project")
    }

    /// Parse events.jsonl to find the first real user message
    func titleFromEvents(path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String, type == "user.message",
                  let eventData = json["data"] as? [String: Any],
                  let message = eventData["content"] as? String else {
                continue
            }

            if isRegistrationPrompt(message) { continue }

            let firstLine = message.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
            if firstLine.isEmpty { continue }

            return truncateTitle(firstLine)
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
