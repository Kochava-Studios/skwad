import XCTest
import Foundation
@testable import Skwad

final class SidebarViewHelpersTests: XCTestCase {

    // MARK: - Agent Row Display

    func testAgentDisplayTitleReturnsTerminalTitleDirectly() {
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
        let name = URL(fileURLWithPath: "/Users/test/src/my-project").lastPathComponent
        XCTAssertEqual(name, "my-project")
    }

    func testHandlesSingleComponentPath() {
        let name = URL(fileURLWithPath: "/project").lastPathComponent
        XCTAssertEqual(name, "project")
    }

    func testHandlesPathWithTrailingSlash() {
        let name = URL(fileURLWithPath: "/Users/test/src/my-project/").lastPathComponent
        XCTAssertEqual(name, "my-project")
    }

    // MARK: - Drag and Drop

    func testAgentIdIsValidUuidString() {
        let agent = Agent(name: "Test", folder: "/path")
        XCTAssertNotNil(UUID(uuidString: agent.id.uuidString))
    }

    func testUuidStringRoundtrip() {
        let originalId = UUID()
        let parsed = UUID(uuidString: originalId.uuidString)
        XCTAssertEqual(parsed, originalId)
    }

    func testInvalidUuidStringReturnsNil() {
        XCTAssertNil(UUID(uuidString: "not-a-uuid"))
    }

    // MARK: - Notification Names

    func testShowNewAgentSheetNotificationNameIsCorrect() {
        XCTAssertEqual(Notification.Name.showNewAgentSheet.rawValue, "showNewAgentSheet")
    }
}
