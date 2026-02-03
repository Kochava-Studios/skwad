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

    func testDisplayTitleStripsLeadingIndicators() {
        var agent = Agent(name: "Test", folder: "/tmp")
        agent.terminalTitle = "✳ claude"
        XCTAssertEqual(agent.displayTitle, "claude")
    }
}
