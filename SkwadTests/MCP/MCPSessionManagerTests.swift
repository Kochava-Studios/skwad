import Testing
import Foundation
@testable import Skwad

@Suite("MCPSessionManager")
struct MCPSessionManagerTests {

    // MARK: - Session Creation

    @Suite("Session Creation")
    struct SessionCreationTests {

        @Test("creates session with unique id")
        func createsSessionWithUniqueId() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session = await manager.createSession(for: agentId)

            #expect(!session.id.isEmpty)
            #expect(session.agentId == agentId)
        }

        @Test("creates different ids for different agents")
        func createsDifferentIds() async {
            let manager = MCPSessionManager()
            let agentId1 = UUID()
            let agentId2 = UUID()

            let session1 = await manager.createSession(for: agentId1)
            let session2 = await manager.createSession(for: agentId2)

            #expect(session1.id != session2.id)
        }

        @Test("replaces existing session for same agent")
        func replacesExistingForSameAgent() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session1 = await manager.createSession(for: agentId)
            let session2 = await manager.createSession(for: agentId)

            // New session should have different id
            #expect(session1.id != session2.id)

            // Only new session should be retrievable
            let retrievedById1 = await manager.getSession(id: session1.id)
            let retrievedById2 = await manager.getSession(id: session2.id)

            #expect(retrievedById1 == nil)  // Old session removed
            #expect(retrievedById2 != nil)  // New session exists
        }

        @Test("session has valid timestamps")
        func sessionHasValidTimestamps() async {
            let manager = MCPSessionManager()
            let agentId = UUID()
            let beforeCreation = Date()

            let session = await manager.createSession(for: agentId)

            #expect(session.createdAt >= beforeCreation)
            #expect(session.lastActivity >= beforeCreation)
        }
    }

    // MARK: - Session Retrieval

    @Suite("Session Retrieval")
    struct SessionRetrievalTests {

        @Test("retrieves session by id")
        func retrievesById() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let created = await manager.createSession(for: agentId)
            let retrieved = await manager.getSession(id: created.id)

            #expect(retrieved != nil)
            #expect(retrieved?.agentId == agentId)
        }

        @Test("retrieves session by agentId")
        func retrievesByAgentId() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let created = await manager.createSession(for: agentId)
            let retrieved = await manager.getSession(for: agentId)

            #expect(retrieved != nil)
            #expect(retrieved?.id == created.id)
        }

        @Test("returns nil for unknown session id")
        func returnsNilForUnknownId() async {
            let manager = MCPSessionManager()

            let retrieved = await manager.getSession(id: "unknown-id")

            #expect(retrieved == nil)
        }

        @Test("returns nil for unknown agent id")
        func returnsNilForUnknownAgentId() async {
            let manager = MCPSessionManager()

            let retrieved = await manager.getSession(for: UUID())

            #expect(retrieved == nil)
        }
    }

    // MARK: - Session Removal

    @Suite("Session Removal")
    struct SessionRemovalTests {

        @Test("removes session by id")
        func removesById() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session = await manager.createSession(for: agentId)
            await manager.removeSession(id: session.id)

            let retrieved = await manager.getSession(id: session.id)
            #expect(retrieved == nil)
        }

        @Test("removes session by agent id")
        func removesByAgentId() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session = await manager.createSession(for: agentId)
            await manager.removeSession(for: agentId)

            let retrieved = await manager.getSession(for: agentId)
            #expect(retrieved == nil)

            // Should also not be retrievable by session id
            let retrievedById = await manager.getSession(id: session.id)
            #expect(retrievedById == nil)
        }

        @Test("clears both mappings on removal")
        func clearsBothMappings() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session = await manager.createSession(for: agentId)
            await manager.removeSession(id: session.id)

            // Both lookups should fail
            let byId = await manager.getSession(id: session.id)
            let byAgent = await manager.getSession(for: agentId)

            #expect(byId == nil)
            #expect(byAgent == nil)
        }
    }

    // MARK: - Stale Cleanup

    @Suite("Stale Cleanup")
    struct StaleCleanupTests {

        @Test("removes sessions older than timeout")
        func removesOldSessions() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            _ = await manager.createSession(for: agentId)

            // Use a very short timeout (0 seconds means all sessions are stale)
            await manager.cleanupStaleSessions(olderThan: 0)

            let retrieved = await manager.getSession(for: agentId)
            #expect(retrieved == nil)
        }

        @Test("preserves recent sessions")
        func preservesRecentSessions() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            _ = await manager.createSession(for: agentId)

            // Use a long timeout
            await manager.cleanupStaleSessions(olderThan: 3600)

            let retrieved = await manager.getSession(for: agentId)
            #expect(retrieved != nil)
        }

        @Test("allSessions returns all active sessions")
        func allSessionsReturnsAll() async {
            let manager = MCPSessionManager()

            _ = await manager.createSession(for: UUID())
            _ = await manager.createSession(for: UUID())
            _ = await manager.createSession(for: UUID())

            let all = await manager.allSessions()
            #expect(all.count == 3)
        }
    }

    // MARK: - Activity Update

    @Suite("Activity Update")
    struct ActivityUpdateTests {

        @Test("updateActivity updates lastActivity timestamp")
        func updateActivityUpdatesTimestamp() async {
            let manager = MCPSessionManager()
            let agentId = UUID()

            let session = await manager.createSession(for: agentId)
            let originalActivity = session.lastActivity

            // Small delay to ensure time difference
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

            await manager.updateActivity(sessionId: session.id)

            let updated = await manager.getSession(id: session.id)
            #expect(updated?.lastActivity ?? originalActivity > originalActivity)
        }
    }
}
