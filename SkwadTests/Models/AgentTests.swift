import XCTest
@testable import Skwad

final class AgentTests: XCTestCase {

    func testCreatesWithDefaultValues() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertEqual(agent.name, "Test")
        XCTAssertEqual(agent.folder, "/tmp/test")
        XCTAssertEqual(agent.agentType, "claude")
        XCTAssertEqual(agent.status, .idle)
        XCTAssertFalse(agent.isRegistered)
    }

    func testCreatesFromFolderPath() {
        let agent = Agent(folder: "/Users/test/my-project")
        XCTAssertEqual(agent.name, "my-project")
        XCTAssertEqual(agent.folder, "/Users/test/my-project")
    }

    func testStatusColors() {
        XCTAssertEqual(AgentStatus.idle.color, .green)
        XCTAssertEqual(AgentStatus.running.color, .orange)
        XCTAssertEqual(AgentStatus.input.color, .red)
        XCTAssertEqual(AgentStatus.error.color, .red)
    }

    func testDetectsImageAvatar() {
        let agent = Agent(name: "Test", avatar: "data:image/png;base64,abc123", folder: "/tmp")
        XCTAssertTrue(agent.isImageAvatar)
    }

    func testReturnsEmojiAvatar() {
        let agent = Agent(name: "Test", avatar: "🚀", folder: "/tmp")
        XCTAssertEqual(agent.emojiAvatar, "🚀")
        XCTAssertFalse(agent.isImageAvatar)
    }

    func testDisplayTitleReturnsTerminalTitle() {
        var agent = Agent(name: "Test", folder: "/tmp")
        // displayTitle returns terminalTitle directly - cleaning happens in AgentManager.updateTitle()
        agent.terminalTitle = "claude"
        XCTAssertEqual(agent.displayTitle, "claude")
    }

    func testMarkdownFileHistoryStartsEmpty() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertTrue(agent.markdownFileHistory.isEmpty)
    }

    func testMarkdownFilePathStartsNil() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertNil(agent.markdownFilePath)
    }

    // MARK: - Companion

    func testCompanionDefaultsToFalse() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertFalse(agent.isCompanion)
        XCTAssertNil(agent.createdBy)
    }

    func testCompanionCreation() {
        let ownerId = UUID()
        let agent = Agent(name: "Companion", folder: "/tmp/test", createdBy: ownerId, isCompanion: true)
        XCTAssertTrue(agent.isCompanion)
        XCTAssertEqual(agent.createdBy, ownerId)
    }

    func testCompanionCodableRoundTrip() throws {
        let ownerId = UUID()
        let original = Agent(name: "Companion", avatar: "🤖", folder: "/tmp/test", createdBy: ownerId, isCompanion: true)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.createdBy, ownerId)
        XCTAssertTrue(decoded.isCompanion)
    }

    func testNonCompanionCodableRoundTrip() throws {
        let original = Agent(name: "Regular", folder: "/tmp/test")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertFalse(decoded.isCompanion)
        XCTAssertNil(decoded.createdBy)
    }

    func testDecodingWithoutIsCompanionDefaultsToFalse() throws {
        // Simulate old data without isCompanion field
        let json = """
        {"id":"\(UUID().uuidString)","name":"Old","folder":"/tmp","agentType":"claude"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertFalse(decoded.isCompanion)
        XCTAssertNil(decoded.createdBy)
    }

    // MARK: - Shell Agent

    func testIsShellForShellAgent() {
        let agent = Agent(name: "Shell", folder: "/tmp", agentType: "shell")
        XCTAssertTrue(agent.isShell)
    }

    func testIsShellFalseForClaudeAgent() {
        let agent = Agent(name: "Claude", folder: "/tmp", agentType: "claude")
        XCTAssertFalse(agent.isShell)
    }

    // MARK: - Pending Start

    func testIsPendingStartDefaultsFalse() {
        let agent = Agent(name: "Test", folder: "/tmp", agentType: "shell")
        XCTAssertFalse(agent.isPendingStart)
    }

    func testIsPendingStartDefaultsFalseForFolderInit() {
        let agent = Agent(folder: "/tmp", agentType: "shell")
        XCTAssertFalse(agent.isPendingStart)
    }

    // MARK: - Metadata

    func testMetadataStartsEmpty() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertTrue(agent.metadata.isEmpty)
    }

    func testMetadataNotPersisted() throws {
        var original = Agent(name: "Test", folder: "/tmp/test")
        original.metadata = ["cwd": "/tmp", "model": "opus"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        // metadata is not in CodingKeys, so it should be empty after decode
        XCTAssertTrue(decoded.metadata.isEmpty)
    }

    // MARK: - Working Folder

    func testWorkingFolderDefaultsToFolder() {
        let agent = Agent(name: "Test", folder: "/Users/test/repo")
        XCTAssertEqual(agent.workingFolder, "/Users/test/repo")
    }

    func testWorkingFolderReturnsCwdWhenDifferentRoot() {
        var agent = Agent(name: "Test", folder: "/Users/test/repo")
        agent.metadata["cwd"] = "/Users/test/repo-worktree"
        XCTAssertEqual(agent.workingFolder, "/Users/test/repo-worktree")
    }

    func testWorkingFolderIgnoresSubdirectory() {
        var agent = Agent(name: "Test", folder: "/Users/test/repo")
        agent.metadata["cwd"] = "/Users/test/repo/frontend"
        XCTAssertEqual(agent.workingFolder, "/Users/test/repo")
    }

    func testWorkingFolderIgnoresExactMatch() {
        var agent = Agent(name: "Test", folder: "/Users/test/repo")
        agent.metadata["cwd"] = "/Users/test/repo"
        XCTAssertEqual(agent.workingFolder, "/Users/test/repo")
    }

    func testWorkingFolderWithTrailingSlashFolder() {
        var agent = Agent(name: "Test", folder: "/Users/test/repo/")
        agent.metadata["cwd"] = "/Users/test/repo-worktree"
        XCTAssertEqual(agent.workingFolder, "/Users/test/repo-worktree")
    }

    // MARK: - Resume/Fork Session

    func testResumeSessionIdStartsNil() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertNil(agent.resumeSessionId)
    }

    func testForkSessionDefaultsFalse() {
        let agent = Agent(name: "Test", folder: "/tmp/test")
        XCTAssertFalse(agent.forkSession)
    }
}
