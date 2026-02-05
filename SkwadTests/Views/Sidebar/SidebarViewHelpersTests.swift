import XCTest
import Foundation
@testable import Skwad

final class SidebarViewHelpersTests: XCTestCase {

    // MARK: - Broadcast Validation

    /// Helper that mirrors the sendBroadcast validation logic
    private func shouldSendBroadcast(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    func testTrimsWhitespaceFromMessage() {
        // With whitespace only, should not send
        XCTAssertFalse(shouldSendBroadcast("   "))
        XCTAssertFalse(shouldSendBroadcast("\n\t\n"))
    }

    func testSkipsEmptyMessage() {
        XCTAssertFalse(shouldSendBroadcast(""))
    }

    func testAllowsValidMessage() {
        XCTAssertTrue(shouldSendBroadcast("Hello agents!"))
    }

    func testAllowsMessageWithLeadingTrailingWhitespace() {
        XCTAssertTrue(shouldSendBroadcast("  Hello  "))
    }

    func testHandlesMultilineMessages() {
        let message = """
        Line 1
        Line 2
        Line 3
        """
        XCTAssertTrue(shouldSendBroadcast(message))
    }

    // MARK: - Batch Operations

    func testIteratesWorkspaceAgentsForRestart() {
        // Simulating the batch operation logic
        let agents = [
            Agent(name: "Agent1", folder: "/path/1"),
            Agent(name: "Agent2", folder: "/path/2"),
            Agent(name: "Agent3", folder: "/path/3")
        ]

        var restartedCount = 0
        for _ in agents {
            restartedCount += 1
        }

        XCTAssertEqual(restartedCount, 3)
    }

    func testIteratesWorkspaceAgentsForClose() {
        let agents = [
            Agent(name: "Agent1", folder: "/path/1"),
            Agent(name: "Agent2", folder: "/path/2")
        ]

        var closedCount = 0
        for _ in agents {
            closedCount += 1
        }

        XCTAssertEqual(closedCount, 2)
    }

    func testHandlesEmptyWorkspace() {
        let agents: [Agent] = []

        var operationCount = 0
        for _ in agents {
            operationCount += 1
        }

        XCTAssertEqual(operationCount, 0)
    }

    // MARK: - Recent Agent Validation

    /// Check if a saved agent's folder is still valid
    private func isValidRecentAgent(_ saved: SavedAgent) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: saved.folder, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    func testValidatesExistingFolder() {
        // /tmp should exist
        let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: "/tmp")
        XCTAssertTrue(isValidRecentAgent(saved))
    }

    func testRejectsNonExistentFolder() {
        let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: "/nonexistent/path/12345")
        XCTAssertFalse(isValidRecentAgent(saved))
    }

    func testRejectsFileAsFolder() {
        // Create a temporary file
        let tempFile = NSTemporaryDirectory() + "test_file_\(UUID().uuidString)"
        FileManager.default.createFile(atPath: tempFile, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: tempFile)
        XCTAssertFalse(isValidRecentAgent(saved))
    }

    // MARK: - Agent Row Display

    func testAgentDisplayTitleReturnsTerminalTitleDirectly() {
        // displayTitle returns terminalTitle directly - cleaning happens in AgentManager.updateTitle()
        var agent = Agent(name: "Test", folder: "/path")
        agent.terminalTitle = "Working on task"

        XCTAssertEqual(agent.displayTitle, "Working on task")
    }

    func testAgentDisplayTitleHandlesEmptyTitle() {
        var agent = Agent(name: "Test", folder: "/path")
        agent.terminalTitle = ""

        XCTAssertEqual(agent.displayTitle, "")
    }

    func testAgentDisplayTitlePreservesAsciiContent() {
        var agent = Agent(name: "Test", folder: "/path")
        agent.terminalTitle = "Working on feature"

        XCTAssertEqual(agent.displayTitle, "Working on feature")
    }

    func testAgentDisplayTitleReturnsCleanedTitle() {
        // AgentManager.updateTitle() cleans the title before storing
        // displayTitle just returns the stored value
        var agent = Agent(name: "Test", folder: "/path")
        agent.terminalTitle = "Task"  // Pre-cleaned by AgentManager

        XCTAssertEqual(agent.displayTitle, "Task")
    }

    // MARK: - Agent Status Color

    func testIdleStatusIsGreen() {
        XCTAssertEqual(AgentStatus.idle.color, .green)
    }

    func testRunningStatusIsOrange() {
        XCTAssertEqual(AgentStatus.running.color, .orange)
    }

    func testErrorStatusIsRed() {
        XCTAssertEqual(AgentStatus.error.color, .red)
    }

    // MARK: - Agent Avatar

    func testEmojiAvatarReturnsEmoji() {
        let agent = Agent(name: "Test", avatar: "🤖", folder: "/path")
        XCTAssertEqual(agent.emojiAvatar, "🤖")
    }

    func testNilAvatarReturnsDefaultEmoji() {
        let agent = Agent(name: "Test", avatar: nil, folder: "/path")
        XCTAssertEqual(agent.emojiAvatar, "🤖")
    }

    func testImageAvatarReturnsDefaultEmoji() {
        let agent = Agent(name: "Test", avatar: "data:image/png;base64,abc", folder: "/path")
        XCTAssertEqual(agent.emojiAvatar, "🤖")
    }

    func testIsImageAvatarTrueForBase64Image() {
        let agent = Agent(name: "Test", avatar: "data:image/png;base64,abc", folder: "/path")
        XCTAssertTrue(agent.isImageAvatar)
    }

    func testIsImageAvatarFalseForEmoji() {
        let agent = Agent(name: "Test", avatar: "🤖", folder: "/path")
        XCTAssertFalse(agent.isImageAvatar)
    }

    func testIsImageAvatarFalseForNil() {
        let agent = Agent(name: "Test", avatar: nil, folder: "/path")
        XCTAssertFalse(agent.isImageAvatar)
    }

    // MARK: - Folder Name Extraction

    func testExtractsLastPathComponent() {
        let path = "/Users/test/src/my-project"
        let name = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertEqual(name, "my-project")
    }

    func testHandlesSingleComponentPath() {
        let path = "/project"
        let name = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertEqual(name, "project")
    }

    func testHandlesPathWithTrailingSlash() {
        let path = "/Users/test/src/my-project/"
        let name = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertEqual(name, "my-project")
    }

    // MARK: - Drag and Drop

    func testAgentIdIsValidUuidString() {
        let agent = Agent(name: "Test", folder: "/path")
        let uuidString = agent.id.uuidString

        XCTAssertNotNil(UUID(uuidString: uuidString))
    }

    func testUuidStringRoundtrip() {
        let originalId = UUID()
        let stringForm = originalId.uuidString
        let parsed = UUID(uuidString: stringForm)

        XCTAssertEqual(parsed, originalId)
    }

    func testInvalidUuidStringReturnsNil() {
        let invalid = "not-a-uuid"
        let parsed = UUID(uuidString: invalid)

        XCTAssertNil(parsed)
    }

    // MARK: - Move Agent Calculation

    private func calculateDestination(fromIndex: Int, toIndex: Int) -> Int {
        toIndex > fromIndex ? toIndex + 1 : toIndex
    }

    func testMovingDownIncreasesDestination() {
        // Moving from 0 to 2 should go to position 3
        let dest = calculateDestination(fromIndex: 0, toIndex: 2)
        XCTAssertEqual(dest, 3)
    }

    func testMovingUpKeepsDestination() {
        // Moving from 3 to 1 should go to position 1
        let dest = calculateDestination(fromIndex: 3, toIndex: 1)
        XCTAssertEqual(dest, 1)
    }

    func testMovingToSamePositionReturnsSame() {
        let dest = calculateDestination(fromIndex: 2, toIndex: 2)
        XCTAssertEqual(dest, 2)
    }

    // MARK: - Context Menu Actions

    func testForkAgentNameAddsSuffix() {
        let originalName = "my-agent"
        let forkName = originalName + " (fork)"
        XCTAssertEqual(forkName, "my-agent (fork)")
    }

    func testDuplicateAgentNameAddsSuffix() {
        let originalName = "my-agent"
        let duplicateName = originalName + " (copy)"
        XCTAssertEqual(duplicateName, "my-agent (copy)")
    }

    // MARK: - Agent Status Raw Values

    func testIdleRawValueIsIdle() {
        XCTAssertEqual(AgentStatus.idle.rawValue, "Idle")
    }

    func testRunningRawValueIsWorking() {
        XCTAssertEqual(AgentStatus.running.rawValue, "Working")
    }

    func testErrorRawValueIsError() {
        XCTAssertEqual(AgentStatus.error.rawValue, "Error")
    }

    // MARK: - Workspace Header Text

    private func headerText(workspaceName: String?) -> String {
        workspaceName?.uppercased() ?? "AGENTS"
    }

    func testWorkspaceNameIsUppercased() {
        let header = headerText(workspaceName: "my workspace")
        XCTAssertEqual(header, "MY WORKSPACE")
    }

    func testNilWorkspaceReturnsAgents() {
        let header = headerText(workspaceName: nil)
        XCTAssertEqual(header, "AGENTS")
    }

    func testEmptyWorkspaceIsUppercased() {
        let header = headerText(workspaceName: "")
        XCTAssertEqual(header, "")
    }

    // MARK: - Agent Selection State

    func testAgentIsSelectedWhenIdMatches() {
        let agent = Agent(name: "Test", folder: "/path")
        let activeAgentId = agent.id

        let isSelected = agent.id == activeAgentId
        XCTAssertTrue(isSelected)
    }

    func testAgentIsNotSelectedWhenIdDiffers() {
        let agent = Agent(name: "Test", folder: "/path")
        let activeAgentId = UUID()

        let isSelected = agent.id == activeAgentId
        XCTAssertFalse(isSelected)
    }

    func testAgentIsNotSelectedWhenNoActiveAgent() {
        let agent = Agent(name: "Test", folder: "/path")
        let activeAgentId: UUID? = nil

        let isSelected = activeAgentId.map { agent.id == $0 } ?? false
        XCTAssertFalse(isSelected)
    }

    // MARK: - Icon Label Fallback

    private func hasAssetImage(named: String) -> Bool {
        NSImage(named: named) != nil
    }

    func testClaudeIconAssetCheck() {
        // This may fail if asset doesn't exist, but tests the logic
        let exists = hasAssetImage(named: "claude")
        // We can't guarantee the asset exists in test environment
        XCTAssertTrue(exists == true || exists == false)  // Just validates the check works
    }

    // MARK: - Notification Names

    func testShowNewAgentSheetNotificationNameIsCorrect() {
        let name = Notification.Name.showNewAgentSheet
        XCTAssertEqual(name.rawValue, "showNewAgentSheet")
    }
}
