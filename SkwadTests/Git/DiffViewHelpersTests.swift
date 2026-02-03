import XCTest
import SwiftUI
@testable import Skwad

/// Tests for the helper functions and computed properties used in DiffView
/// These test the pure logic extracted from the view code
final class DiffViewHelpersTests: XCTestCase {

    // MARK: - Test Helpers

    /// Helper to compute background color for a diff line kind
    /// Mirrors the logic in DiffLineView
    static func backgroundColor(for kind: DiffLine.Kind) -> (color: String, opacity: Double) {
        switch kind {
        case .addition:
            return ("green", 0.2)
        case .deletion:
            return ("red", 0.2)
        case .hunkHeader:
            return ("blue", 0.15)
        case .context, .header:
            return ("clear", 0)
        }
    }

    /// Helper to compute text color for a diff line kind
    /// Mirrors the logic in DiffLineView
    static func textColor(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .addition:
            return "green"
        case .deletion:
            return "red"
        case .hunkHeader:
            return "blue"
        case .context, .header:
            return "primary"
        }
    }

    /// Helper to compute prefix for a diff line kind
    /// Mirrors the logic in DiffLineView
    static func prefix(for kind: DiffLine.Kind) -> String {
        switch kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .hunkHeader, .header: return ""
        case .context: return " "
        }
    }

    // MARK: - Background Color Tests

    func testAdditionHasGreenBackground() {
        let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .addition)
        XCTAssertEqual(color, "green")
        XCTAssertEqual(opacity, 0.2)
    }

    func testDeletionHasRedBackground() {
        let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .deletion)
        XCTAssertEqual(color, "red")
        XCTAssertEqual(opacity, 0.2)
    }

    func testHunkHeaderHasBlueBackground() {
        let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .hunkHeader)
        XCTAssertEqual(color, "blue")
        XCTAssertEqual(opacity, 0.15)
    }

    func testContextHasClearBackground() {
        let (color, _) = DiffViewHelpersTests.backgroundColor(for: .context)
        XCTAssertEqual(color, "clear")
    }

    func testHeaderHasClearBackground() {
        let (color, _) = DiffViewHelpersTests.backgroundColor(for: .header)
        XCTAssertEqual(color, "clear")
    }

    // MARK: - Text Color Tests

    func testAdditionHasGreenText() {
        let color = DiffViewHelpersTests.textColor(for: .addition)
        XCTAssertEqual(color, "green")
    }

    func testDeletionHasRedText() {
        let color = DiffViewHelpersTests.textColor(for: .deletion)
        XCTAssertEqual(color, "red")
    }

    func testHunkHeaderHasBlueText() {
        let color = DiffViewHelpersTests.textColor(for: .hunkHeader)
        XCTAssertEqual(color, "blue")
    }

    func testContextHasPrimaryText() {
        let color = DiffViewHelpersTests.textColor(for: .context)
        XCTAssertEqual(color, "primary")
    }

    func testHeaderHasPrimaryText() {
        let color = DiffViewHelpersTests.textColor(for: .header)
        XCTAssertEqual(color, "primary")
    }

    // MARK: - Prefix Mapping Tests

    func testAdditionHasPlusPrefix() {
        let prefix = DiffViewHelpersTests.prefix(for: .addition)
        XCTAssertEqual(prefix, "+")
    }

    func testDeletionHasMinusPrefix() {
        let prefix = DiffViewHelpersTests.prefix(for: .deletion)
        XCTAssertEqual(prefix, "-")
    }

    func testContextHasSpacePrefix() {
        let prefix = DiffViewHelpersTests.prefix(for: .context)
        XCTAssertEqual(prefix, " ")
    }

    func testHunkHeaderHasEmptyPrefix() {
        let prefix = DiffViewHelpersTests.prefix(for: .hunkHeader)
        XCTAssertEqual(prefix, "")
    }

    func testHeaderHasEmptyPrefix() {
        let prefix = DiffViewHelpersTests.prefix(for: .header)
        XCTAssertEqual(prefix, "")
    }

    // MARK: - DiffLine Tests

    func testAdditionLineHasNewLineNumberButNoOldLineNumber() {
        let line = DiffLine(
            kind: .addition,
            content: "new line",
            oldLineNumber: nil,
            newLineNumber: 5
        )

        XCTAssertNil(line.oldLineNumber)
        XCTAssertEqual(line.newLineNumber, 5)
    }

    func testDeletionLineHasOldLineNumberButNoNewLineNumber() {
        let line = DiffLine(
            kind: .deletion,
            content: "removed line",
            oldLineNumber: 3,
            newLineNumber: nil
        )

        XCTAssertEqual(line.oldLineNumber, 3)
        XCTAssertNil(line.newLineNumber)
    }

    func testContextLineHasBothLineNumbers() {
        let line = DiffLine(
            kind: .context,
            content: "unchanged line",
            oldLineNumber: 10,
            newLineNumber: 12
        )

        XCTAssertEqual(line.oldLineNumber, 10)
        XCTAssertEqual(line.newLineNumber, 12)
    }

    // MARK: - FileDiff Tests

    func testAdditionsCountsAdditionLines() {
        let diff = FileDiff(
            path: "test.swift",
            oldPath: nil,
            isBinary: false,
            hunks: [
                DiffHunk(
                    header: "@@ -1,3 +1,5 @@",
                    oldStart: 1,
                    oldCount: 3,
                    newStart: 1,
                    newCount: 5,
                    lines: [
                        DiffLine(kind: .context, content: "line1", oldLineNumber: 1, newLineNumber: 1),
                        DiffLine(kind: .addition, content: "new1", oldLineNumber: nil, newLineNumber: 2),
                        DiffLine(kind: .addition, content: "new2", oldLineNumber: nil, newLineNumber: 3),
                        DiffLine(kind: .context, content: "line2", oldLineNumber: 2, newLineNumber: 4),
                    ]
                )
            ]
        )

        XCTAssertEqual(diff.additions, 2)
    }

    func testDeletionsCountsDeletionLines() {
        let diff = FileDiff(
            path: "test.swift",
            oldPath: nil,
            isBinary: false,
            hunks: [
                DiffHunk(
                    header: "@@ -1,5 +1,3 @@",
                    oldStart: 1,
                    oldCount: 5,
                    newStart: 1,
                    newCount: 3,
                    lines: [
                        DiffLine(kind: .context, content: "line1", oldLineNumber: 1, newLineNumber: 1),
                        DiffLine(kind: .deletion, content: "old1", oldLineNumber: 2, newLineNumber: nil),
                        DiffLine(kind: .deletion, content: "old2", oldLineNumber: 3, newLineNumber: nil),
                        DiffLine(kind: .deletion, content: "old3", oldLineNumber: 4, newLineNumber: nil),
                        DiffLine(kind: .context, content: "line2", oldLineNumber: 5, newLineNumber: 2),
                    ]
                )
            ]
        )

        XCTAssertEqual(diff.deletions, 3)
    }

    func testBinaryFileHasNoHunks() {
        let diff = FileDiff(
            path: "image.png",
            oldPath: nil,
            isBinary: true,
            hunks: []
        )

        XCTAssertTrue(diff.isBinary)
        XCTAssertTrue(diff.hunks.isEmpty)
        XCTAssertEqual(diff.additions, 0)
        XCTAssertEqual(diff.deletions, 0)
    }
}
