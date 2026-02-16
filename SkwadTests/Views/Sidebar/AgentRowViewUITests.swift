import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

final class AgentRowViewUITests: XCTestCase {

    // MARK: - Fixtures

    private func makeAgent(name: String = "skwad", avatar: String = "🐱", folder: String = "/src/skwad", status: AgentStatus = .idle, title: String = "") -> Agent {
        var agent = Agent(name: name, avatar: avatar, folder: folder)
        agent.status = status
        agent.terminalTitle = title
        return agent
    }

    private func makeCompanion(name: String = "shell", avatar: String = "🐚", status: AgentStatus = .running) -> Agent {
        var agent = Agent(name: name, avatar: avatar, folder: "/src/skwad")
        agent.status = status
        return agent
    }

    // MARK: - Normal Mode: Shows All Text

    func testNormalModeShowsAgentName() throws {
        let row = AgentRowView(agent: makeAgent(name: "skwad"), isSelected: false, isCompact: false)
        let texts = try row.normalBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("skwad"), "Normal mode should show agent name")
    }

    func testNormalModeShowsDisplayTitle() throws {
        let row = AgentRowView(agent: makeAgent(title: "Working on feature"), isSelected: false, isCompact: false)
        let texts = try row.normalBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("Working on feature"), "Normal mode should show display title")
    }

    func testNormalModeShowsReadyWhenTitleEmpty() throws {
        let row = AgentRowView(agent: makeAgent(title: ""), isSelected: false, isCompact: false)
        let texts = try row.normalBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("Ready"), "Normal mode should show 'Ready' when title is empty")
    }

    func testNormalModeShowsFolderName() throws {
        let row = AgentRowView(agent: makeAgent(folder: "/Users/test/src/my-project"), isSelected: false, isCompact: false)
        let texts = try row.normalBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("my-project"), "Normal mode should show folder name")
    }

    func testNormalModeShowsCompanionNames() throws {
        let companion = makeCompanion(name: "helper")
        let row = AgentRowView(agent: makeAgent(), isSelected: false, companions: [companion], isCompact: false)
        let texts = try row.normalBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("helper"), "Normal mode should show companion names")
    }

    // MARK: - Compact Mode: Hides Labels

    func testCompactModeHidesDisplayTitle() throws {
        let row = AgentRowView(agent: makeAgent(title: "Working on feature"), isSelected: false, isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertFalse(texts.contains("Working on feature"), "Compact mode should hide display title")
    }

    func testCompactModeHidesReadyText() throws {
        let row = AgentRowView(agent: makeAgent(title: ""), isSelected: false, isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertFalse(texts.contains("Ready"), "Compact mode should hide 'Ready' text")
    }

    func testCompactModeHidesFolderName() throws {
        let row = AgentRowView(agent: makeAgent(folder: "/Users/test/src/my-project"), isSelected: false, isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertFalse(texts.contains("my-project"), "Compact mode should hide folder name")
    }

    func testCompactModeHidesCompanionNames() throws {
        let companion = makeCompanion(name: "helper")
        let row = AgentRowView(agent: makeAgent(), isSelected: false, companions: [companion], isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertFalse(texts.contains("helper"), "Compact mode should hide companion names")
        XCTAssertFalse(texts.contains("shell"), "Compact mode should hide companion names")
    }

    // MARK: - Compact Mode: Shows Avatar

    func testCompactModeShowsAvatar() throws {
        let row = AgentRowView(agent: makeAgent(avatar: "🐱"), isSelected: false, isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("🐱"), "Compact mode should still show the avatar")
    }

    func testCompactModeShowsCompanionAvatars() throws {
        let companion = makeCompanion(name: "helper", avatar: "🐚")
        let row = AgentRowView(agent: makeAgent(avatar: "🐱"), isSelected: false, companions: [companion], isCompact: true)
        let texts = try row.compactBody.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("🐱"), "Compact mode should show main avatar")
        XCTAssertTrue(texts.contains("🐚"), "Compact mode should show companion avatar")
    }

    // MARK: - Selection State Works In Both Modes

    func testNormalModeSelectedState() throws {
        let row = AgentRowView(agent: makeAgent(), isSelected: true, isCompact: false)
        _ = try row.normalBody.inspect().findAll(ViewType.Text.self)
    }

    func testCompactModeSelectedState() throws {
        let row = AgentRowView(agent: makeAgent(), isSelected: true, isCompact: true)
        _ = try row.compactBody.inspect()
    }
}
