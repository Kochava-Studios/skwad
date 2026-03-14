import Foundation

enum TitleUtils {

    /// Check if a string is a skwad-injected prompt (not a valid title candidate)
    static func isRegistrationPrompt(_ text: String) -> Bool {
        let lc = text.lowercased()
        return lc.contains("you are part of a team of agents")
            || lc.contains("register with the skwad")
            || lc.contains("list other agents names and project")
            || lc.contains("check your inbox for messages")
    }

    /// Check if a string is a valid title candidate
    static func isValidTitle(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if isRegistrationPrompt(trimmed) { return false }
        if trimmed.hasPrefix("<local-command-") { return false }
        if trimmed == "/clear" { return false }
        return true
    }

    /// Extract a display title from raw text: first line, truncated to 80 chars
    static func extractTitle(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let firstLine = trimmed.components(separatedBy: "\n").first ?? trimmed
        guard !firstLine.isEmpty else { return nil }
        return truncate(firstLine)
    }

    /// Truncate a title to 80 chars max (77 + "...")
    static func truncate(_ text: String) -> String {
        let firstLine = text.components(separatedBy: "\n").first ?? text
        if firstLine.count > 80 {
            return String(firstLine.prefix(77)) + "..."
        }
        return firstLine
    }
}
