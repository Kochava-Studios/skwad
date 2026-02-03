import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

final class DiffViewUITests: XCTestCase {

    // MARK: - Test Fixtures

    private func createSimpleDiff() -> FileDiff {
        FileDiff(
            path: "test.swift",
            oldPath: nil,
            isBinary: false,
            hunks: [
                DiffHunk(
                    header: "@@ -1,3 +1,4 @@",
                    oldStart: 1,
                    oldCount: 3,
                    newStart: 1,
                    newCount: 4,
                    lines: [
                        DiffLine(kind: .hunkHeader, content: "@@ -1,3 +1,4 @@", oldLineNumber: nil, newLineNumber: nil),
                        DiffLine(kind: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
                        DiffLine(kind: .deletion, content: "let old = true", oldLineNumber: 2, newLineNumber: nil),
                        DiffLine(kind: .addition, content: "let new = true", oldLineNumber: nil, newLineNumber: 2),
                        DiffLine(kind: .addition, content: "let another = false", oldLineNumber: nil, newLineNumber: 3),
                        DiffLine(kind: .context, content: "", oldLineNumber: 3, newLineNumber: 4),
                    ]
                )
            ]
        )
    }

    private func createBinaryDiff() -> FileDiff {
        FileDiff(
            path: "image.png",
            oldPath: nil,
            isBinary: true,
            hunks: []
        )
    }

    private func createEmptyDiff() -> FileDiff {
        FileDiff(
            path: "empty.swift",
            oldPath: nil,
            isBinary: false,
            hunks: []
        )
    }

    private func createMultiHunkDiff() -> FileDiff {
        FileDiff(
            path: "multi.swift",
            oldPath: nil,
            isBinary: false,
            hunks: [
                DiffHunk(
                    header: "@@ -1,2 +1,3 @@",
                    oldStart: 1, oldCount: 2, newStart: 1, newCount: 3,
                    lines: [
                        DiffLine(kind: .hunkHeader, content: "@@ -1,2 +1,3 @@", oldLineNumber: nil, newLineNumber: nil),
                        DiffLine(kind: .addition, content: "// Header comment", oldLineNumber: nil, newLineNumber: 1),
                    ]
                ),
                DiffHunk(
                    header: "@@ -10,2 +11,3 @@",
                    oldStart: 10, oldCount: 2, newStart: 11, newCount: 3,
                    lines: [
                        DiffLine(kind: .hunkHeader, content: "@@ -10,2 +11,3 @@", oldLineNumber: nil, newLineNumber: nil),
                        DiffLine(kind: .deletion, content: "// Old comment", oldLineNumber: 10, newLineNumber: nil),
                        DiffLine(kind: .addition, content: "// New comment", oldLineNumber: nil, newLineNumber: 11),
                    ]
                )
            ]
        )
    }

    // MARK: - DiffView Tests

    func testDiffViewRendersScrollView() throws {
        let view = DiffView(diff: createSimpleDiff())
        let scrollView = try? view.inspect().find(ViewType.ScrollView.self)
        XCTAssertNotNil(scrollView, "DiffView should contain ScrollView")
    }

    func testDiffViewRendersHunks() throws {
        let view = DiffView(diff: createSimpleDiff())
        // Should find the hunk content
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "DiffView should contain VStack for hunks")
    }

    func testBinaryFileShowsBinaryMessage() throws {
        let view = DiffView(diff: createBinaryDiff())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasBinaryText = texts.contains { text in
            (try? text.string().contains("Binary")) ?? false
        }
        XCTAssertTrue(hasBinaryText, "Binary file should show 'Binary file' message")
    }

    func testEmptyDiffShowsNoChanges() throws {
        let view = DiffView(diff: createEmptyDiff())
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasNoChanges = texts.contains { text in
            (try? text.string().contains("No changes")) ?? false
        }
        XCTAssertTrue(hasNoChanges, "Empty diff should show 'No changes' message")
    }

    // MARK: - HunkView Tests

    func testHunkViewRendersLines() throws {
        let hunk = createSimpleDiff().hunks[0]
        let view = HunkView(hunk: hunk)
        let vStack = try? view.inspect().find(ViewType.VStack.self)
        XCTAssertNotNil(vStack, "HunkView should contain VStack")
    }

    // MARK: - DiffLineView Tests

    func testAdditionLineRenders() throws {
        let line = DiffLine(kind: .addition, content: "let x = 1", oldLineNumber: nil, newLineNumber: 5)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasAdditionContent = texts.contains { text in
            (try? text.string().contains("let x = 1")) ?? false
        }
        XCTAssertTrue(hasAdditionContent, "Addition line should show content")
    }

    func testDeletionLineRenders() throws {
        let line = DiffLine(kind: .deletion, content: "let y = 2", oldLineNumber: 10, newLineNumber: nil)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasDeletionContent = texts.contains { text in
            (try? text.string().contains("let y = 2")) ?? false
        }
        XCTAssertTrue(hasDeletionContent, "Deletion line should show content")
    }

    func testContextLineRenders() throws {
        let line = DiffLine(kind: .context, content: "import SwiftUI", oldLineNumber: 1, newLineNumber: 1)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasContextContent = texts.contains { text in
            (try? text.string().contains("import SwiftUI")) ?? false
        }
        XCTAssertTrue(hasContextContent, "Context line should show content")
    }

    func testHunkHeaderLineRenders() throws {
        let line = DiffLine(kind: .hunkHeader, content: "@@ -1,5 +1,7 @@", oldLineNumber: nil, newLineNumber: nil)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasHeader = texts.contains { text in
            (try? text.string().contains("@@")) ?? false
        }
        XCTAssertTrue(hasHeader, "Hunk header line should show header")
    }

    func testLineNumbersRender() throws {
        let line = DiffLine(kind: .context, content: "code", oldLineNumber: 42, newLineNumber: 43)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let has42 = texts.contains { text in
            (try? text.string() == "42") ?? false
        }
        let has43 = texts.contains { text in
            (try? text.string() == "43") ?? false
        }
        XCTAssertTrue(has42, "Should show old line number 42")
        XCTAssertTrue(has43, "Should show new line number 43")
    }

    func testAdditionLineHasPlusPrefix() throws {
        let line = DiffLine(kind: .addition, content: "new code", oldLineNumber: nil, newLineNumber: 1)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasPlus = texts.contains { text in
            (try? text.string().hasPrefix("+")) ?? false
        }
        XCTAssertTrue(hasPlus, "Addition line should have + prefix")
    }

    func testDeletionLineHasMinusPrefix() throws {
        let line = DiffLine(kind: .deletion, content: "old code", oldLineNumber: 1, newLineNumber: nil)
        let view = DiffLineView(line: line)

        let texts = try view.inspect().findAll(ViewType.Text.self)
        let hasMinus = texts.contains { text in
            (try? text.string().hasPrefix("-")) ?? false
        }
        XCTAssertTrue(hasMinus, "Deletion line should have - prefix")
    }

    // MARK: - FileDiff Computed Properties

    func testFileDiffAdditionsCount() {
        let diff = createSimpleDiff()
        XCTAssertEqual(diff.additions, 2, "Should count 2 additions")
    }

    func testFileDiffDeletionsCount() {
        let diff = createSimpleDiff()
        XCTAssertEqual(diff.deletions, 1, "Should count 1 deletion")
    }

    func testMultiHunkDiffAdditionsCount() {
        let diff = createMultiHunkDiff()
        XCTAssertEqual(diff.additions, 2, "Should count additions across all hunks")
    }

    func testMultiHunkDiffDeletionsCount() {
        let diff = createMultiHunkDiff()
        XCTAssertEqual(diff.deletions, 1, "Should count deletions across all hunks")
    }

    func testBinaryDiffHasZeroChanges() {
        let diff = createBinaryDiff()
        XCTAssertEqual(diff.additions, 0)
        XCTAssertEqual(diff.deletions, 0)
    }
}
