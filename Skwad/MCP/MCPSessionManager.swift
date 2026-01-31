import Foundation

// MARK: - MCP Session

struct MCPSession {
    let id: String
    let agentId: UUID
    let createdAt: Date
    var lastActivity: Date

    init(agentId: UUID) {
        self.id = UUID().uuidString
        self.agentId = agentId
        self.createdAt = Date()
        self.lastActivity = Date()
    }
}

// MARK: - Session Manager

actor MCPSessionManager {
    private var sessions: [String: MCPSession] = [:]
    private var agentToSession: [UUID: String] = [:]

    func createSession(for agentId: UUID) -> MCPSession {
        // Remove existing session for this agent if any
        if let existingSessionId = agentToSession[agentId] {
            sessions.removeValue(forKey: existingSessionId)
        }

        let session = MCPSession(agentId: agentId)
        sessions[session.id] = session
        agentToSession[agentId] = session.id
        return session
    }

    func getSession(id: String) -> MCPSession? {
        sessions[id]
    }

    func getSession(for agentId: UUID) -> MCPSession? {
        guard let sessionId = agentToSession[agentId] else { return nil }
        return sessions[sessionId]
    }

    func updateActivity(sessionId: String) {
        sessions[sessionId]?.lastActivity = Date()
    }

    func removeSession(id: String) {
        if let session = sessions[id] {
            agentToSession.removeValue(forKey: session.agentId)
            sessions.removeValue(forKey: id)
        }
    }

    func removeSession(for agentId: UUID) {
        if let sessionId = agentToSession[agentId] {
            sessions.removeValue(forKey: sessionId)
            agentToSession.removeValue(forKey: agentId)
        }
    }

    func allSessions() -> [MCPSession] {
        Array(sessions.values)
    }

    func cleanupStaleSessions(olderThan timeout: TimeInterval = 3600) {
        let cutoff = Date().addingTimeInterval(-timeout)
        for (id, session) in sessions where session.lastActivity < cutoff {
            removeSession(id: id)
        }
    }
}
