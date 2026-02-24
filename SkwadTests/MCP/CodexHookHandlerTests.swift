import XCTest
import Logging
@testable import Skwad

final class CodexHookHandlerTests: XCTestCase {

    private var service: AgentCoordinator!
    private var provider: MockAgentDataProvider!
    private var handler: CodexHookHandler!
    private var agent: Agent!

    override func setUp() async throws {
        service = AgentCoordinator.shared
        agent = Agent(name: "TestCodex", folder: "/test/codex")
        provider = MockAgentDataProvider(
            agents: [agent],
            workspaces: [Workspace(name: "Test", agentIds: [agent.id])]
        )
        await service.setAgentDataProvider(provider)
        handler = CodexHookHandler(mcpService: service, logger: Logger(label: "test"))
    }

    // MARK: - Activity Status

    func testAgentTurnCompleteSetsIdle() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "codex",
            "hook": "notify",
            "status": "idle",
            "payload": [
                "type": "agent-turn-complete",
                "thread-id": "thread-123",
                "turn-id": "turn-456",
                "cwd": "/test/codex",
                "input-messages": ["hello"],
                "last-assistant-message": "Hi. How can I help?"
            ] as [String: Any]
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertEqual(status, .idle)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.status, .idle)
    }

    func testUnknownEventTypeReturnsNil() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "codex",
            "hook": "notify",
            "status": "idle",
            "payload": [
                "type": "unknown-event",
                "thread-id": "thread-123"
            ] as [String: Any]
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertNil(status)
    }

    func testMissingPayloadReturnsNil() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "codex",
            "hook": "notify",
            "status": "idle"
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertNil(status)
    }

    func testMissingEventTypeReturnsNil() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "codex",
            "hook": "notify",
            "status": "idle",
            "payload": [
                "thread-id": "thread-123"
            ] as [String: Any]
        ]

        let status = await handler.handleActivityStatus(agentId: agent.id, json: json)
        XCTAssertNil(status)
    }

    // MARK: - Metadata Extraction

    func testExtractMetadataKnownKeys() {
        let payload: [String: Any] = [
            "type": "agent-turn-complete",
            "cwd": "/Users/test",
            "thread-id": "thread-abc",
            "turn-id": "turn-def",
            "input-messages": ["hello"],
            "last-assistant-message": "Hi"
        ]

        let metadata = handler.extractMetadata(from: payload)
        XCTAssertEqual(metadata["cwd"], "/Users/test")
        XCTAssertEqual(metadata["thread-id"], "thread-abc")
        XCTAssertEqual(metadata["turn-id"], "turn-def")
        // type, input-messages, last-assistant-message are not in knownKeys
        XCTAssertNil(metadata["type"])
        XCTAssertNil(metadata["last-assistant-message"])
    }

    func testExtractMetadataSkipsEmptyStrings() {
        let payload: [String: Any] = [
            "cwd": "",
            "thread-id": "thread-abc"
        ]

        let metadata = handler.extractMetadata(from: payload)
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata["thread-id"], "thread-abc")
    }

    func testExtractMetadataNilPayload() {
        let metadata = handler.extractMetadata(from: nil)
        XCTAssertTrue(metadata.isEmpty)
    }

    func testMetadataStoredOnAgent() async {
        let json: [String: Any] = [
            "agent_id": agent.id.uuidString,
            "agent": "codex",
            "hook": "notify",
            "status": "idle",
            "payload": [
                "type": "agent-turn-complete",
                "cwd": "/project/dir",
                "thread-id": "thread-999",
                "turn-id": "turn-888",
                "input-messages": ["fix the bug"],
                "last-assistant-message": "Done!"
            ] as [String: Any]
        ]

        _ = await handler.handleActivityStatus(agentId: agent.id, json: json)

        let updated = await provider.getAgent(id: agent.id)
        XCTAssertEqual(updated?.metadata["cwd"], "/project/dir")
        XCTAssertEqual(updated?.metadata["thread-id"], "thread-999")
        XCTAssertEqual(updated?.metadata["turn-id"], "turn-888")
    }
}
