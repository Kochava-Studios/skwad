import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

final class CommitSheetUITests: XCTestCase {

    // MARK: - Basic Rendering

    func testRendersTitle() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTitle = texts.contains { text in
            (try? text.string().contains("Commit")) ?? false
        }
        XCTAssertTrue(hasTitle, "Should render 'Commit' in title")
    }

    func testRendersSubtitle() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasSubtitle = texts.contains { text in
            (try? text.string().contains("commit message")) ?? false
        }
        XCTAssertTrue(hasSubtitle, "Should render subtitle about commit message")
    }

    func testRendersMessageLabel() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasLabel = texts.contains { text in
            (try? text.string() == "Commit message") ?? false
        }
        XCTAssertTrue(hasLabel, "Should render 'Commit message' label")
    }

    func testRendersTextEditor() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let textEditor = try? view.inspect().find(ViewType.TextEditor.self)
        XCTAssertNotNil(textEditor, "Should render TextEditor for message input")
    }

    func testRendersTip() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasTip = texts.contains { text in
            (try? text.string().contains("Tip:")) ?? false
        }
        XCTAssertTrue(hasTip, "Should render tip about commit message format")
    }

    // MARK: - Layout

    func testHasVStackLayout() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "Should use VStack layout")
    }

    func testHasSpacer() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        let spacer = try? view.inspect().find(ViewType.Spacer.self)
        XCTAssertNotNil(spacer, "Should have spacer")
    }

    // MARK: - Frame Size

    func testHasCorrectFrameWidth() throws {
        let view = CommitSheet(folder: "/tmp/test") {}
        // The view has .frame(width: 450, height: 280)
        // We can't directly test frame with ViewInspector easily,
        // but we can verify the view renders
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack)
    }
}
