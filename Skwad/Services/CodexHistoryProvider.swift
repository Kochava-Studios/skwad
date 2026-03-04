import Foundation
import SQLite3

struct CodexHistoryProvider: ConversationHistoryProvider {

    private static let dbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.codex/state_5.sqlite"
    }()

    func loadSessions(for folder: String) -> [SessionSummary] {
        guard FileManager.default.fileExists(atPath: Self.dbPath) else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(Self.dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let query = """
            SELECT id, rollout_path, title, updated_at
            FROM threads
            WHERE cwd = ?1 AND archived = 0
            ORDER BY updated_at DESC
            LIMIT 20
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (folder as NSString).utf8String, -1, nil)

        var summaries: [SessionSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let rolloutPath = String(cString: sqlite3_column_text(stmt, 1))
            let title = String(cString: sqlite3_column_text(stmt, 2))
            let updatedAt = sqlite3_column_int64(stmt, 3)
            let timestamp = Date(timeIntervalSince1970: Double(updatedAt))

            let resolvedTitle = resolveTitle(title, rolloutPath: rolloutPath)
            summaries.append(SessionSummary(id: id, title: resolvedTitle, timestamp: timestamp, messageCount: 0))
        }

        return summaries
    }

    func deleteSession(id: String, folder: String) {
        // Delete the rollout file if it exists
        if let rolloutPath = rolloutPath(for: id) {
            try? FileManager.default.removeItem(atPath: rolloutPath)
        }

        // Mark as archived in the DB
        guard FileManager.default.fileExists(atPath: Self.dbPath) else { return }
        var db: OpaquePointer?
        guard sqlite3_open(Self.dbPath, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "UPDATE threads SET archived = 1 WHERE id = ?1"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    // MARK: - Title Resolution

    /// If the DB title is empty or a skwad registration prompt, parse the rollout file for a real title
    private func resolveTitle(_ dbTitle: String, rolloutPath: String) -> String {
        if !dbTitle.isEmpty && !isRegistrationPrompt(dbTitle) {
            return truncateTitle(dbTitle)
        }

        // Fall back to parsing the rollout JSONL
        return titleFromRollout(path: rolloutPath) ?? ""
    }

    private func isRegistrationPrompt(_ text: String) -> Bool {
        let lc = text.lowercased()
        return lc.contains("you are part of a team of agents")
            || lc.contains("register with the skwad")
            || lc.contains("list other agents names and project")
    }

    /// Parse a Codex rollout JSONL file to find the first real user message
    func titleFromRollout(path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let payload = json["payload"] as? [String: Any],
                  let type = payload["type"] as? String,
                  type == "user_message",
                  let message = payload["message"] as? String else {
                continue
            }

            if isRegistrationPrompt(message) { continue }

            let firstLine = message.components(separatedBy: "\n").first ?? message
            let trimmedLine = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }

            return truncateTitle(trimmedLine)
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

    /// Look up the rollout_path for a thread ID
    private func rolloutPath(for id: String) -> String? {
        guard FileManager.default.fileExists(atPath: Self.dbPath) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(Self.dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let query = "SELECT rollout_path FROM threads WHERE id = ?1"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }
}
