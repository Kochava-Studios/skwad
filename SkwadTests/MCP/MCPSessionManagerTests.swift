import XCTest
import Foundation
@testable import Skwad

final class MCPSessionManagerTests: XCTestCase {

    // MARK: - Session Creation

    func testCreatesSessionWithUniqueId() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session = await manager.createSession(for: agentId)

        XCTAssertFalse(session.id.isEmpty)
        XCTAssertEqual(session.agentId, agentId)
    }

    func testCreatesDifferentIdsForDifferentAgents() async {
        let manager = MCPSessionManager()
        let agentId1 = UUID()
        let agentId2 = UUID()

        let session1 = await manager.createSession(for: agentId1)
        let session2 = await manager.createSession(for: agentId2)

        XCTAssertNotEqual(session1.id, session2.id)
    }

    func testReplacesExistingSessionForSameAgent() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session1 = await manager.createSession(for: agentId)
        let session2 = await manager.createSession(for: agentId)

        // New session should have different id
        XCTAssertNotEqual(session1.id, session2.id)

        // Only new session should be retrievable
        let retrievedById1 = await manager.getSession(id: session1.id)
        let retrievedById2 = await manager.getSession(id: session2.id)

        XCTAssertNil(retrievedById1)  // Old session removed
        XCTAssertNotNil(retrievedById2)  // New session exists
    }

    func testSessionHasValidTimestamps() async {
        let manager = MCPSessionManager()
        let agentId = UUID()
        let beforeCreation = Date()

        let session = await manager.createSession(for: agentId)

        XCTAssertGreaterThanOrEqual(session.createdAt, beforeCreation)
        XCTAssertGreaterThanOrEqual(session.lastActivity, beforeCreation)
    }

    // MARK: - Session Retrieval

    func testRetrievesSessionById() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let created = await manager.createSession(for: agentId)
        let retrieved = await manager.getSession(id: created.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.agentId, agentId)
    }

    func testRetrievesSessionByAgentId() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let created = await manager.createSession(for: agentId)
        let retrieved = await manager.getSession(for: agentId)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, created.id)
    }

    func testReturnsNilForUnknownSessionId() async {
        let manager = MCPSessionManager()

        let retrieved = await manager.getSession(id: "unknown-id")

        XCTAssertNil(retrieved)
    }

    func testReturnsNilForUnknownAgentId() async {
        let manager = MCPSessionManager()

        let retrieved = await manager.getSession(for: UUID())

        XCTAssertNil(retrieved)
    }

    // MARK: - Session Removal

    func testRemovesSessionById() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session = await manager.createSession(for: agentId)
        await manager.removeSession(id: session.id)

        let retrieved = await manager.getSession(id: session.id)
        XCTAssertNil(retrieved)
    }

    func testRemovesSessionByAgentId() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session = await manager.createSession(for: agentId)
        await manager.removeSession(for: agentId)

        let retrieved = await manager.getSession(for: agentId)
        XCTAssertNil(retrieved)

        // Should also not be retrievable by session id
        let retrievedById = await manager.getSession(id: session.id)
        XCTAssertNil(retrievedById)
    }

    func testClearsBothMappingsOnRemoval() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session = await manager.createSession(for: agentId)
        await manager.removeSession(id: session.id)

        // Both lookups should fail
        let byId = await manager.getSession(id: session.id)
        let byAgent = await manager.getSession(for: agentId)

        XCTAssertNil(byId)
        XCTAssertNil(byAgent)
    }

    // MARK: - Stale Cleanup

    func testRemovesSessionsOlderThanTimeout() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        _ = await manager.createSession(for: agentId)

        // Use a very short timeout (0 seconds means all sessions are stale)
        await manager.cleanupStaleSessions(olderThan: 0)

        let retrieved = await manager.getSession(for: agentId)
        XCTAssertNil(retrieved)
    }

    func testPreservesRecentSessions() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        _ = await manager.createSession(for: agentId)

        // Use a long timeout
        await manager.cleanupStaleSessions(olderThan: 3600)

        let retrieved = await manager.getSession(for: agentId)
        XCTAssertNotNil(retrieved)
    }

    func testAllSessionsReturnsAll() async {
        let manager = MCPSessionManager()

        _ = await manager.createSession(for: UUID())
        _ = await manager.createSession(for: UUID())
        _ = await manager.createSession(for: UUID())

        let all = await manager.allSessions()
        XCTAssertEqual(all.count, 3)
    }

    // MARK: - Activity Update

    func testUpdateActivityUpdatesTimestamp() async {
        let manager = MCPSessionManager()
        let agentId = UUID()

        let session = await manager.createSession(for: agentId)
        let originalActivity = session.lastActivity

        // Small delay to ensure time difference
        try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        await manager.updateActivity(sessionId: session.id)

        let updated = await manager.getSession(id: session.id)
        XCTAssertGreaterThan(updated?.lastActivity ?? originalActivity, originalActivity)
    }
}
