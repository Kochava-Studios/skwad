import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

@MainActor
final class WorkspaceSheetUITests: XCTestCase {

    // MARK: - New Workspace Mode

    func testNewWorkspaceTitle() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasNewTitle = texts.contains { text in
            (try? text.string() == "New Workspace") ?? false
        }
        XCTAssertTrue(hasNewTitle, "Should show 'New Workspace' title")
    }

    func testRendersNameField() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let textField = try? view.inspect().find(ViewType.TextField.self)
        XCTAssertNotNil(textField, "Should render name TextField")
    }

    func testRendersNameLabel() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasNameLabel = texts.contains { text in
            (try? text.string() == "Name") ?? false
        }
        XCTAssertTrue(hasNameLabel, "Should show 'Name' label")
    }

    func testRendersColorLabel() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasColorLabel = texts.contains { text in
            (try? text.string() == "Color") ?? false
        }
        XCTAssertTrue(hasColorLabel, "Should show 'Color' label")
    }

    func testRendersCancelButton() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        let hasCancelButton = buttons.contains { button in
            let texts = try? button.findAll(ViewType.Text.self)
            return texts?.contains { (try? $0.string() == "Cancel") ?? false } ?? false
        }
        XCTAssertTrue(hasCancelButton, "Should have Cancel button")
    }

    func testRendersCreateButton() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        let hasCreateButton = buttons.contains { button in
            let texts = try? button.findAll(ViewType.Text.self)
            return texts?.contains { (try? $0.string() == "Create") ?? false } ?? false
        }
        XCTAssertTrue(hasCreateButton, "Should have Create button in new mode")
    }

    // MARK: - Edit Workspace Mode

    func testEditWorkspaceTitle() throws {
        let workspace = Workspace(name: "Test", colorHex: WorkspaceColor.blue.rawValue)
        let view = WorkspaceSheet(workspace: workspace)
            .environment(AgentManager())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasEditTitle = texts.contains { text in
            (try? text.string() == "Edit Workspace") ?? false
        }
        XCTAssertTrue(hasEditTitle, "Should show 'Edit Workspace' title in edit mode")
    }

    func testRendersSaveButtonInEditMode() throws {
        let workspace = Workspace(name: "Test", colorHex: WorkspaceColor.blue.rawValue)
        let view = WorkspaceSheet(workspace: workspace)
            .environment(AgentManager())
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        let hasSaveButton = buttons.contains { button in
            let texts = try? button.findAll(ViewType.Text.self)
            return texts?.contains { (try? $0.string() == "Save") ?? false } ?? false
        }
        XCTAssertTrue(hasSaveButton, "Should have Save button in edit mode")
    }

    // MARK: - Color Picker

    func testRendersLazyVGrid() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let grid = try? view.inspect().find(ViewType.LazyVGrid.self)
        XCTAssertNotNil(grid, "Should use LazyVGrid for color picker")
    }

    // MARK: - Layout

    func testHasVStackLayout() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "Should use VStack layout")
    }

    func testHasSpacer() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let spacer = try? view.inspect().find(ViewType.Spacer.self)
        XCTAssertNotNil(spacer, "Should have spacer")
    }

    func testHasHStackForButtons() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let hStacks = try view.inspect().findAll(ViewType.HStack.self)
        XCTAssertGreaterThan(hStacks.count, 0, "Should have HStack for button layout")
    }

    func testHasZStackForPreview() throws {
        let view = WorkspaceSheet()
            .environment(AgentManager())
        let zStack = try? view.inspect().find(ViewType.ZStack.self)
        XCTAssertNotNil(zStack, "Should have ZStack for preview")
    }
}
