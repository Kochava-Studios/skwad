import Foundation
import SwiftUI
import AppKit

enum AgentStatus: String, Codable {
    case idle = "Idle"
    case running = "Working"
    case error = "Error"

    var color: Color {
        switch self {
        case .idle: return .green
        case .running: return .orange
        case .error: return .red
        }
    }
}

struct GitLineStats: Hashable, Codable {
    let insertions: Int
    let deletions: Int
    let files: Int
}

struct Agent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var avatar: String?  // Either emoji or "data:image/png;base64,..."
    var folder: String
    var agentType: String  // Agent type ID (claude, codex, custom1, etc.)
    var createdBy: UUID?  // Agent ID that created this agent (nil if created by user)

    // Runtime state (not persisted)
    var status: AgentStatus = .idle
    var isRegistered: Bool = false  // Set true when agent calls register-agent with MCP
    var terminalTitle: String = ""  // Current terminal title
    var restartToken: UUID = UUID()  // Changes on restart to force terminal recreation
    var gitStats: GitLineStats? = nil
    var markdownFilePath: String? = nil  // Markdown file being previewed (set by MCP tool)
    var markdownFileHistory: [String] = []  // History of markdown files shown (most recent first)

    // Only persist these fields
    enum CodingKeys: String, CodingKey {
        case id, name, avatar, folder, agentType, createdBy
    }

    init(id: UUID = UUID(), name: String, avatar: String? = nil, folder: String, agentType: String = "claude", createdBy: UUID? = nil) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.folder = folder
        self.agentType = agentType
        self.createdBy = createdBy
    }

    /// Create agent from folder path, deriving name from last path component
    init(folder: String, avatar: String? = nil, agentType: String = "claude", createdBy: UUID? = nil) {
        self.id = UUID()
        self.folder = folder
        self.avatar = avatar
        self.agentType = agentType
        self.createdBy = createdBy
        self.name = URL(fileURLWithPath: folder).lastPathComponent
    }

    /// Terminal title (cleaned on update in AgentManager)
    var displayTitle: String {
        terminalTitle
    }

    /// Check if avatar is an image (base64 encoded)
    var isImageAvatar: Bool {
        avatar?.hasPrefix("data:image") ?? false
    }

    /// Get emoji avatar string (returns default if image or nil)
    var emojiAvatar: String {
        if let avatar = avatar, !avatar.hasPrefix("data:") {
            return avatar
        }
        return "🤖"
    }

    /// Get NSImage from base64 avatar data
    var avatarImage: NSImage? {
        guard let avatar = avatar,
              avatar.hasPrefix("data:image"),
              let commaIndex = avatar.firstIndex(of: ",") else {
            return nil
        }
        let base64String = String(avatar[avatar.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return NSImage(data: data)
    }
}
