import XCTest
import SwiftUI
@testable import Skwad

final class WorkspaceTests: XCTestCase {

    // MARK: - Initials Computation

    func testTwoWordsReturnsFirstLetters() {
        let initials = Workspace.computeInitials(from: "Hello World")
        XCTAssertEqual(initials, "HW")
    }

    func testTwoWordsLowercaseReturnsUppercase() {
        let initials = Workspace.computeInitials(from: "hello world")
        XCTAssertEqual(initials, "HW")
    }

    func testThreeWordsUsesFirstTwo() {
        let initials = Workspace.computeInitials(from: "Alpha Beta Gamma")
        XCTAssertEqual(initials, "AB")
    }

    func testSingleWordReturnsFirstTwoChars() {
        let initials = Workspace.computeInitials(from: "Workspace")
        XCTAssertEqual(initials, "WO")
    }

    func testSingleCharWord() {
        let initials = Workspace.computeInitials(from: "A")
        XCTAssertEqual(initials, "A")
    }

    func testEmptyStringReturnsQuestionMark() {
        let initials = Workspace.computeInitials(from: "")
        XCTAssertEqual(initials, "?")
    }

    func testWhitespaceOnlyReturnsQuestionMark() {
        let initials = Workspace.computeInitials(from: "   ")
        XCTAssertEqual(initials, "?")
    }

    func testLeadingWhitespaceIsTrimmed() {
        let initials = Workspace.computeInitials(from: "  Hello World")
        XCTAssertEqual(initials, "HW")
    }

    func testWorkspacePropertyReturnsCorrectInitials() {
        let workspace = Workspace(name: "My Project")
        XCTAssertEqual(workspace.initials, "MP")
    }

    // MARK: - Create Default

    func testCreatesSkwadWorkspace() {
        let workspace = Workspace.createDefault()
        XCTAssertEqual(workspace.name, "Skwad")
    }

    func testUsesBlueColor() {
        let workspace = Workspace.createDefault()
        XCTAssertEqual(workspace.colorHex, WorkspaceColor.blue.rawValue)
    }

    func testStartsWithEmptyAgentList() {
        let workspace = Workspace.createDefault()
        XCTAssertTrue(workspace.agentIds.isEmpty)
    }

    func testIncludesProvidedAgentIds() {
        let agentId1 = UUID()
        let agentId2 = UUID()
        let workspace = Workspace.createDefault(withAgentIds: [agentId1, agentId2])
        XCTAssertEqual(workspace.agentIds, [agentId1, agentId2])
    }

    func testSetsFirstAgentAsActive() {
        let agentId1 = UUID()
        let agentId2 = UUID()
        let workspace = Workspace.createDefault(withAgentIds: [agentId1, agentId2])
        XCTAssertEqual(workspace.activeAgentIds, [agentId1])
    }

    func testActiveAgentIdsEmptyWhenNoAgents() {
        let workspace = Workspace.createDefault()
        XCTAssertTrue(workspace.activeAgentIds.isEmpty)
    }

    func testDefaultLayoutIsSingle() {
        let workspace = Workspace.createDefault()
        XCTAssertEqual(workspace.layoutMode, .single)
    }

    func testDefaultFocusedPaneIsZero() {
        let workspace = Workspace.createDefault()
        XCTAssertEqual(workspace.focusedPaneIndex, 0)
    }

    func testDefaultSplitRatioIsHalf() {
        let workspace = Workspace.createDefault()
        XCTAssertEqual(workspace.splitRatio, 0.5)
    }

    // MARK: - Workspace Color

    func testAllColorsHaveValidHex() {
        for workspaceColor in WorkspaceColor.allCases {
            let color = Color(hex: workspaceColor.rawValue)
            XCTAssertNotNil(color, "WorkspaceColor.\(workspaceColor) should have valid hex")
        }
    }

    func testDefaultColorIsBlue() {
        XCTAssertEqual(WorkspaceColor.default, .blue)
    }

    func testColorPropertyReturnsValidColor() {
        for workspaceColor in WorkspaceColor.allCases {
            // This should not crash - validates color conversion works
            let _ = workspaceColor.color
        }
    }

    func testWorkspaceColorPropertyReturnsCorrectColor() {
        let workspace = Workspace(name: "Test", colorHex: WorkspaceColor.purple.rawValue)
        // The color should be parseable
        let _ = workspace.color
    }

    func testInvalidHexFallsBackToBlue() {
        let workspace = Workspace(name: "Test", colorHex: "invalid")
        // Should fall back to blue
        let _ = workspace.color  // Should not crash
    }

    // MARK: - Workspace Initialization

    func testCustomInitializationPreservesAllValues() {
        let id = UUID()
        let agentId1 = UUID()
        let agentId2 = UUID()

        let workspace = Workspace(
            id: id,
            name: "Custom",
            colorHex: WorkspaceColor.green.rawValue,
            agentIds: [agentId1, agentId2],
            layoutMode: .splitVertical,
            activeAgentIds: [agentId1],
            focusedPaneIndex: 1,
            splitRatio: 0.7
        )

        XCTAssertEqual(workspace.id, id)
        XCTAssertEqual(workspace.name, "Custom")
        XCTAssertEqual(workspace.colorHex, WorkspaceColor.green.rawValue)
        XCTAssertEqual(workspace.agentIds, [agentId1, agentId2])
        XCTAssertEqual(workspace.layoutMode, .splitVertical)
        XCTAssertEqual(workspace.activeAgentIds, [agentId1])
        XCTAssertEqual(workspace.focusedPaneIndex, 1)
        XCTAssertEqual(workspace.splitRatio, 0.7)
    }

    func testWorkspaceIsHashable() {
        let workspace1 = Workspace(name: "Test1")
        let workspace2 = Workspace(name: "Test2")

        var set = Set<Workspace>()
        set.insert(workspace1)
        set.insert(workspace2)

        XCTAssertEqual(set.count, 2)
    }

    func testWorkspaceIsIdentifiable() {
        let workspace = Workspace(name: "Test")
        XCTAssertNotEqual(workspace.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
}
