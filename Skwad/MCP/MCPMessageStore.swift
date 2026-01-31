import Foundation
import Logging

// MARK: - MCP Message Store

/// Actor responsible for managing message storage and retrieval
/// Extracted from MCPService to follow Single Responsibility Principle
actor MCPMessageStore {
    private let logger = Logger(label: "com.skwad.mcp.messagestore")
    private var messages: [MCPMessage] = []

    // MARK: - Message Operations

    /// Add a new message to the store
    func add(_ message: MCPMessage) {
        messages.append(message)
        logger.debug("Message stored: \(message.id)")
    }

    /// Get unread messages for a specific agent
    func getUnread(for agentUUID: String) -> [MCPMessage] {
        messages.filter { $0.to == agentUUID && !$0.isRead }
    }

    /// Mark messages as read for a specific agent
    func markAsRead(for agentUUID: String) {
        for i in messages.indices {
            if messages[i].to == agentUUID && !messages[i].isRead {
                messages[i].isRead = true
            }
        }
        logger.debug("Marked messages as read for agent: \(agentUUID)")
    }

    /// Check if an agent has unread messages
    func hasUnread(for agentUUID: String) -> Bool {
        messages.contains { $0.to == agentUUID && !$0.isRead }
    }

    /// Get the ID of the most recent unread message for an agent
    func getLatestUnreadId(for agentUUID: String) -> UUID? {
        messages.last { $0.to == agentUUID && !$0.isRead }?.id
    }

    // MARK: - Cleanup

    /// Remove old read messages to prevent unbounded growth
    /// Keeps the last 100 read messages
    func cleanup() {
        let readMessages = messages.filter { $0.isRead }
        if readMessages.count > 100 {
            let toRemove = readMessages.count - 100
            var removed = 0
            messages.removeAll { message in
                if message.isRead && removed < toRemove {
                    removed += 1
                    return true
                }
                return false
            }
            logger.debug("[skwad] Cleaned up \(removed) old messages")
        }
    }
}
