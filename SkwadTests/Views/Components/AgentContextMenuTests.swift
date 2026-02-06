import XCTest
@testable import Skwad

final class AgentContextMenuTests: XCTestCase {

    // MARK: - Normal Agent (claude, not companion)

    func testNormalAgentShowsNewCompanion() {
        let agent = Agent(name: "Test", folder: "/path", agentType: "claude")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showNewCompanion)
    }

    func testNormalAgentShowsFork() {
        let agent = Agent(name: "Test", folder: "/path", agentType: "claude")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showFork)
    }

    func testNormalAgentShowsDuplicate() {
        let agent = Agent(name: "Test", folder: "/path", agentType: "claude")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showDuplicate)
    }

    func testNormalAgentShowsMoveToWorkspace() {
        let agent = Agent(name: "Test", folder: "/path", agentType: "claude")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showMoveToWorkspace)
    }

    func testNormalAgentShowsRegister() {
        let agent = Agent(name: "Test", folder: "/path", agentType: "claude")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showRegister)
    }

    // MARK: - Shell Agent (not companion)

    func testShellAgentShowsNewCompanion() {
        let agent = Agent(name: "Shell", folder: "/path", agentType: "shell")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showNewCompanion)
    }

    func testShellAgentShowsFork() {
        let agent = Agent(name: "Shell", folder: "/path", agentType: "shell")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showFork)
    }

    func testShellAgentShowsDuplicate() {
        let agent = Agent(name: "Shell", folder: "/path", agentType: "shell")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showDuplicate)
    }

    func testShellAgentShowsMoveToWorkspace() {
        let agent = Agent(name: "Shell", folder: "/path", agentType: "shell")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showMoveToWorkspace)
    }

    func testShellAgentHidesRegister() {
        let agent = Agent(name: "Shell", folder: "/path", agentType: "shell")
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showRegister)
    }

    // MARK: - Companion Agent (claude)

    func testCompanionHidesNewCompanion() {
        let agent = Agent(name: "Companion", folder: "/path", agentType: "claude", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showNewCompanion)
    }

    func testCompanionHidesFork() {
        let agent = Agent(name: "Companion", folder: "/path", agentType: "claude", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showFork)
    }

    func testCompanionHidesDuplicate() {
        let agent = Agent(name: "Companion", folder: "/path", agentType: "claude", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showDuplicate)
    }

    func testCompanionHidesMoveToWorkspace() {
        let agent = Agent(name: "Companion", folder: "/path", agentType: "claude", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showMoveToWorkspace)
    }

    func testCompanionShowsRegister() {
        let agent = Agent(name: "Companion", folder: "/path", agentType: "claude", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertTrue(visibility.showRegister)
    }

    // MARK: - Shell Companion

    func testShellCompanionHidesNewCompanion() {
        let agent = Agent(name: "ShellComp", folder: "/path", agentType: "shell", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showNewCompanion)
    }

    func testShellCompanionHidesFork() {
        let agent = Agent(name: "ShellComp", folder: "/path", agentType: "shell", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showFork)
    }

    func testShellCompanionHidesDuplicate() {
        let agent = Agent(name: "ShellComp", folder: "/path", agentType: "shell", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showDuplicate)
    }

    func testShellCompanionHidesMoveToWorkspace() {
        let agent = Agent(name: "ShellComp", folder: "/path", agentType: "shell", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showMoveToWorkspace)
    }

    func testShellCompanionHidesRegister() {
        let agent = Agent(name: "ShellComp", folder: "/path", agentType: "shell", createdBy: UUID(), isCompanion: true)
        let visibility = AgentMenuVisibility(agent: agent)
        XCTAssertFalse(visibility.showRegister)
    }
}
