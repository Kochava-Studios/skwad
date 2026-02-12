import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

@MainActor
final class WorkspaceAvatarViewUITests: XCTestCase {

    // MARK: - Test Fixtures

    private func createWorkspace(name: String = "Test Project", color: WorkspaceColor = .blue) -> Workspace {
        Workspace(name: name, colorHex: color.rawValue)
    }

    // MARK: - Basic Rendering

    func testRendersZStack() throws {
        let workspace = createWorkspace()
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should render a ZStack")
    }

    func testRendersInitials() throws {
        let workspace = createWorkspace(name: "Test Project")
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasInitials = texts.contains { text in
            (try? text.string() == "TP") ?? false
        }
        XCTAssertTrue(hasInitials, "Should render initials 'TP' for 'Test Project'")
    }

    func testRendersInitialsForSingleWord() throws {
        let workspace = createWorkspace(name: "Skwad")
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasInitials = texts.contains { text in
            (try? text.string() == "SK") ?? false
        }
        XCTAssertTrue(hasInitials, "Should render initials 'SK' for 'Skwad'")
    }

    // MARK: - Selection State

    func testSelectedStateRenders() throws {
        let workspace = createWorkspace(color: .purple)
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should render when selected")
    }

    func testUnselectedStateRenders() throws {
        let workspace = createWorkspace(color: .purple)
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: false, activityStatus: nil)
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should render when unselected")
    }

    // MARK: - Various Workspace Names

    func testThreeWordName() throws {
        let workspace = createWorkspace(name: "My Cool Project")
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        // Should use first letter of first two words
        let hasInitials = texts.contains { text in
            (try? text.string() == "MC") ?? false
        }
        XCTAssertTrue(hasInitials, "Should render 'MC' for 'My Cool Project'")
    }

    func testEmptyNameShowsQuestionMark() throws {
        let workspace = createWorkspace(name: "")
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasQuestionMark = texts.contains { text in
            (try? text.string() == "?") ?? false
        }
        XCTAssertTrue(hasQuestionMark, "Empty name should show '?'")
    }

    func testSingleCharacterName() throws {
        let workspace = createWorkspace(name: "X")
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let texts = try view.inspect().findAll(ViewType.Text.self)
        // Single char should show just that char
        let hasX = texts.contains { text in
            (try? text.string() == "X") ?? false
        }
        XCTAssertTrue(hasX, "Single char name should show 'X'")
    }

    // MARK: - All Colors Render

    func testAllColorsRender() throws {
        for color in WorkspaceColor.allCases {
            let workspace = Workspace(name: "Test", colorHex: color.rawValue)
            let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
            let zStack = try? view.inspect().find(ViewType.ZStack.self)
            XCTAssertNotNil(zStack, "Should render for color: \(color)")
        }
    }

    // MARK: - Active State

    func testActiveStateRenders() throws {
        let workspace = createWorkspace()
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: .running)
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should render when active")
    }

    func testInactiveStateRenders() throws {
        let workspace = createWorkspace()
        let view = WorkspaceAvatarView(workspace: workspace, isSelected: true, activityStatus: nil)
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should render when inactive")
    }
}
