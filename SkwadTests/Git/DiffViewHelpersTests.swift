import XCTest
import SwiftUI
@testable import Skwad

/// Tests for DiffLine/DiffHunk/FileDiff types and DiffLine.Kind.prefix
final class DiffViewHelpersTests: XCTestCase {

    // MARK: - Prefix Mapping Tests

    func testAdditionHasPlusPrefix() {
        XCTAssertEqual(DiffLine.Kind.addition.prefix, "+")
    }

    func testDeletionHasMinusPrefix() {
        XCTAssertEqual(DiffLine.Kind.deletion.prefix, "-")
    }

    func testContextHasSpacePrefix() {
        XCTAssertEqual(DiffLine.Kind.context.prefix, " ")
    }

    func testHunkHeaderHasEmptyPrefix() {
        XCTAssertEqual(DiffLine.Kind.hunkHeader.prefix, "")
    }

    func testHeaderHasEmptyPrefix() {
        XCTAssertEqual(DiffLine.Kind.header.prefix, "")
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
