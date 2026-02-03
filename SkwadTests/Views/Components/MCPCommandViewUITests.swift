import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

final class MCPCommandViewUITests: XCTestCase {

    let testServerURL = "http://localhost:9876"

    // MARK: - Basic Rendering

    func testRendersWithServerURL() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        // Should find the command text
        let texts = try view.inspect().findAll(ViewType.Text.self)
        XCTAssertFalse(texts.isEmpty, "Should render text elements")
    }

    func testRendersAgentPickerMenu() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        let menu = try? view.inspect().find(ViewType.Menu.self)
        XCTAssertNotNil(menu, "Should render agent picker menu")
    }

    func testRendersCopyButton() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        XCTAssertGreaterThan(buttons.count, 0, "Should render at least one button (copy)")
    }

    // MARK: - Default State

    func testDefaultAgentIsClaude() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        // Claude's default message contains "auto-started"
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasAutoStarted = texts.contains { text in
            (try? text.string().contains("auto-started")) ?? false
        }
        XCTAssertTrue(hasAutoStarted, "Default agent (Claude) should show auto-started message")
    }

    // MARK: - Layout

    func testHasHorizontalStackLayout() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        let hStack = try? view.inspect().find(ViewType.HStack.self)
        XCTAssertNotNil(hStack, "Should use HStack layout")
    }

    func testHasSpacer() throws {
        let view = MCPCommandView(serverURL: testServerURL)
        let spacer = try? view.inspect().find(ViewType.Spacer.self)
        XCTAssertNotNil(spacer, "Should have spacer for layout")
    }

    // MARK: - Customization

    func testAcceptsCustomBackgroundColor() throws {
        let view = MCPCommandView(serverURL: testServerURL, backgroundColor: .red)
        // View should render without error
        let hStack = try? view.inspect().find(ViewType.HStack.self)
        XCTAssertNotNil(hStack)
    }

    func testAcceptsCustomFontSize() throws {
        let view = MCPCommandView(serverURL: testServerURL, fontSize: .title3)
        let hStack = try? view.inspect().find(ViewType.HStack.self)
        XCTAssertNotNil(hStack)
    }

    func testAcceptsCustomIconSize() throws {
        let view = MCPCommandView(serverURL: testServerURL, iconSize: 24)
        let hStack = try? view.inspect().find(ViewType.HStack.self)
        XCTAssertNotNil(hStack)
    }
}
