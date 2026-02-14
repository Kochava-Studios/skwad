import XCTest
import Logging
@testable import Skwad

final class ClaudeHookHandlerTests: XCTestCase {

    private var service: MCPService!
    private var provider: MockAgentDataProvider!
    private var handler: ClaudeHookHandler!
    private var agent: Agent!

    override func setUp() async throws {
        service = MCPService.shared
        agent = Agent(name: "TestAgent", folder: "/test/path")
        provider = MockAgentDataProvider(
            agents: [agent],
            workspaces: [Workspace(name: "Test", agentIds: [agent.id])]
        )
        await service.setAgentDataProvider(provider)
        handler = ClaudeHookHandler(mcpService: service, logger: Logger(label: "test"))
    }

    // MARK: - Register: Scratch Agent (startup only, no resumeSessionId)

    func testScratchAgentStoresStartupSessionId() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-session-123",
            "payload": [String: Any]()
        ]

        let success = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: json)
        XCTAssertTrue(success)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "new-session-123")
    }

    // MARK: - Register: Resume Agent (startup + resume, resumeSessionId set, forkSession = false)

    func testResumeStartupDoesNotSetSessionId() async {
        // Agent has resumeSessionId set (simulating AgentManager.resumeSession)
        await provider.setResumeSessionId(for: agent.id, sessionId: "old-session-789")

        let startupJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-session-456",
            "payload": [String: Any]()
        ]
        let success = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: startupJson)
        XCTAssertTrue(success)

        // Startup should NOT set session ID when resuming
        let updated = await provider.getAgent(id: agent.id)
        XCTAssertNil(updated?.sessionId)
    }

    func testResumeEventSetsResumedSessionId() async {
        // Agent has resumeSessionId set (simulating AgentManager.resumeSession)
        await provider.setResumeSessionId(for: agent.id, sessionId: "old-session-789")

        // Startup arrives first — should not set sessionId
        let startupJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-session-456",
            "payload": [String: Any]()
        ]
        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: startupJson)

        // Resume arrives second — should set the old session ID
        let resumeJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "resume",
            "session_id": "old-session-789",
            "payload": [String: Any]()
        ]
        let success = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: resumeJson)
        XCTAssertTrue(success)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "old-session-789")
    }

    func testResumeWorksEvenIfResumeArrivesFirst() async {
        // Agent has resumeSessionId set
        await provider.setResumeSessionId(for: agent.id, sessionId: "old-session-789")

        // Resume arrives FIRST (race condition)
        let resumeJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "resume",
            "session_id": "old-session-789",
            "payload": [String: Any]()
        ]
        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: resumeJson)

        // Startup arrives SECOND
        let startupJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-session-456",
            "payload": [String: Any]()
        ]
        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: startupJson)

        // Should still have the resumed session ID
        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "old-session-789")
    }

    // MARK: - Register: Fork Agent (startup + resume, forkSession = true)

    func testForkStartupSetsNewSessionId() async {
        await provider.setResumeSessionId(for: agent.id, sessionId: "old-original-session")
        await provider.setForkSession(for: agent.id, fork: true)

        let startupJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-forked-session",
            "payload": [String: Any]()
        ]
        let success = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: startupJson)
        XCTAssertTrue(success)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "new-forked-session")
    }

    func testForkResumeDoesNotOverwrite() async {
        await provider.setResumeSessionId(for: agent.id, sessionId: "old-original-session")
        await provider.setForkSession(for: agent.id, fork: true)

        // Startup sets the new forked session
        let startupJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "new-forked-session",
            "payload": [String: Any]()
        ]
        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: startupJson)

        // Resume arrives — should NOT overwrite
        let resumeJson: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "resume",
            "session_id": "old-original-session",
            "payload": [String: Any]()
        ]
        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: resumeJson)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "new-forked-session")
    }

    // MARK: - Register: Backward Compatibility (no source field)

    func testNoSourceDefaultsToStartup() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "session_id": "session-no-source",
            "payload": [String: Any]()
        ]

        let success = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: json)
        XCTAssertTrue(success)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.sessionId, "session-no-source")
    }

    // MARK: - Register: Metadata Extraction

    func testRegisterExtractsMetadata() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "claude",
            "source": "startup",
            "session_id": "session-meta",
            "payload": [
                "cwd": "/some/path",
                "model": "claude-sonnet-4-5-20250929",
                "transcript_path": "/tmp/transcript.jsonl"
            ] as [String: Any]
        ]

        _ = await handler.handleRegister(agentId: agent.id, agentIdString: agent.id.uuidString, json: json)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.metadata["cwd"], "/some/path")
        XCTAssertEqual(updated?.metadata["model"], "claude-sonnet-4-5-20250929")
        XCTAssertEqual(updated?.metadata["transcript_path"], "/tmp/transcript.jsonl")
    }

    // MARK: - Activity Status

    func testActivityStatusRunning() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "status": "running",
            "payload": [String: Any]()
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertEqual(status, .running)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.status, .running)
    }

    func testActivityStatusIdle() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "status": "idle",
            "payload": [String: Any]()
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertEqual(status, .idle)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.status, .idle)
    }

    func testActivityStatusInvalid() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "status": "banana",
            "payload": [String: Any]()
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertNil(status)
    }

    // MARK: - Metadata Extraction

    func testExtractMetadataKnownKeys() {
        let payload: [String: Any] = [
            "transcript_path": "/tmp/foo.jsonl",
            "cwd": "/Users/test",
            "model": "claude-sonnet-4-5-20250929",
            "session_id": "sess-123",
            "unknown_key": "ignored"
        ]

        let metadata = handler.extractMetadata(from: payload)
        XCTAssertEqual(metadata.count, 4)
        XCTAssertEqual(metadata["transcript_path"], "/tmp/foo.jsonl")
        XCTAssertEqual(metadata["cwd"], "/Users/test")
        XCTAssertEqual(metadata["model"], "claude-sonnet-4-5-20250929")
        XCTAssertEqual(metadata["session_id"], "sess-123")
    }

    func testExtractMetadataSkipsEmptyStrings() {
        let payload: [String: Any] = [
            "cwd": "",
            "model": "claude-sonnet-4-5-20250929"
        ]

        let metadata = handler.extractMetadata(from: payload)
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata["model"], "claude-sonnet-4-5-20250929")
    }

    func testExtractMetadataNilPayload() {
        let metadata = handler.extractMetadata(from: nil)
        XCTAssertTrue(metadata.isEmpty)
    }
}
