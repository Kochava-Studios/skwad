import XCTest
import Logging
@testable import Skwad

final class ClaudeHookHandlerTests: XCTestCase {

    private var service: AgentCoordinator!
    private var provider: MockAgentDataProvider!
    private var handler: ClaudeHookHandler!
    private var agent: Agent!

    override func setUp() async throws {
        service = AgentCoordinator.shared
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

    // MARK: - lastAssistantMessageFromTranscript

    private func writeTempTranscript(_ lines: [String]) -> String {
        let path = NSTemporaryDirectory() + "test-transcript-\(UUID().uuidString).jsonl"
        let content = lines.joined(separator: "\n")
        FileManager.default.createFile(atPath: path, contents: content.data(using: .utf8))
        addTeardownBlock { try? FileManager.default.removeItem(atPath: path) }
        return path
    }

    private func userLine(_ text: String) -> String {
        #"{"type":"user","message":{"content":"\#(text)"}}"#
    }

    private func userLineArray(_ text: String) -> String {
        #"{"type":"user","message":{"content":[{"type":"text","text":"\#(text)"}]}}"#
    }

    private func assistantLine(_ text: String) -> String {
        #"{"type":"assistant","message":{"content":[{"type":"text","text":"\#(text)"}]}}"#
    }

    // nil path → nil
    func testTranscriptNilPath() {
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: nil))
    }

    // File doesn't exist → nil
    func testTranscriptMissingFile() {
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: "/nonexistent/path.jsonl"))
    }

    // Empty file → nil
    func testTranscriptEmptyFile() {
        let path = writeTempTranscript([])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Invalid JSON lines → nil
    func testTranscriptInvalidJson() {
        let path = writeTempTranscript(["not json", "{broken"])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Lines missing "type" field → nil
    func testTranscriptMissingTypeField() {
        let path = writeTempTranscript([
            #"{"message":{"content":[{"type":"text","text":"hello"}]}}"#,
        ])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Only user messages, no assistant → nil
    func testTranscriptUserOnly() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
        ])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Normal conversation — returns assistant text
    func testTranscriptReturnsAssistantMessage() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            assistantLine("I found the issue. Should I proceed?"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "I found the issue. Should I proceed?")
    }

    // Multiple turns — returns last assistant message
    func testTranscriptReturnsLastAssistantMessage() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            assistantLine("First response"),
            userLine("Now fix tests"),
            assistantLine("Tests are passing now."),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Tests are passing now.")
    }

    // Content as plain string (real transcript format)
    func testTranscriptPlainStringContent() {
        let path = writeTempTranscript([
            #"{"type":"user","message":{"role":"user","content":"Fix the bug"}}"#,
            #"{"type":"assistant","message":{"role":"assistant","content":"Done!"}}"#,
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Done!")
    }

    // Assistant message missing "message" field → skip it
    func testTranscriptAssistantMissingMessageField() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            #"{"type":"assistant"}"#,
        ])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Assistant content has no text parts → skip it
    func testTranscriptAssistantNoTextParts() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"123"}]}}"#,
        ])
        XCTAssertNil(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path))
    }

    // Assistant with extra fields — still works
    func testTranscriptExtraFieldsInJson() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            #"{"type":"assistant","extra":"ignored","message":{"content":[{"type":"text","text":"Done!"}],"model":"claude"}}"#,
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Done!")
    }

    // Non-user type between user and assistant (e.g. system) — skipped, still returns message
    func testTranscriptSkipsNonUserTypes() {
        let path = writeTempTranscript([
            userLine("Fix the bug"),
            #"{"type":"system","message":"some event"}"#,
            assistantLine("Done!"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Done!")
    }

    // Registration prompt → returns empty string (skip signal)
    func testTranscriptRegistrationResponseReturnsEmpty() {
        let path = writeTempTranscript([
            userLine(TerminalCommandBuilder.registrationUserPrompt),
            assistantLine("Here are the agents in the skwad..."),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "")
    }

    // Registration prompt with array content format → returns empty string
    func testTranscriptRegistrationResponseArrayFormat() {
        let path = writeTempTranscript([
            userLineArray(TerminalCommandBuilder.registrationUserPrompt),
            assistantLine("Here are the agents..."),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "")
    }

    // Registration happened first, real work followed → returns last assistant message (not empty)
    func testTranscriptRegistrationThenRealWork() {
        let path = writeTempTranscript([
            userLine(TerminalCommandBuilder.registrationUserPrompt),
            assistantLine("Here are the agents..."),
            userLine("Now fix the tests"),
            assistantLine("Tests are all passing now."),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Tests are all passing now.")
    }

    // User message missing "message" field → returns assistant text (not registration)
    func testTranscriptUserMissingMessageField() {
        let path = writeTempTranscript([
            #"{"type":"user"}"#,
            assistantLine("Response"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Response")
    }

    // User message missing "content" → returns assistant text (not registration)
    func testTranscriptUserMissingContent() {
        let path = writeTempTranscript([
            #"{"type":"user","message":{}}"#,
            assistantLine("Response"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Response")
    }

    // User content has only tool_use (no text) → returns assistant text (not registration)
    func testTranscriptUserNoTextParts() {
        let path = writeTempTranscript([
            #"{"type":"user","message":{"content":[{"type":"tool_use","id":"123"}]}}"#,
            assistantLine("Response"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Response")
    }

    // Only assistant, no preceding user → returns assistant text
    func testTranscriptAssistantOnly() {
        let path = writeTempTranscript([
            assistantLine("Hello!"),
        ])
        XCTAssertEqual(ClaudeHookHandler.lastAssistantMessageFromTranscript(path: path), "Hello!")
    }
}
