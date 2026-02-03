import Testing
import SwiftUI
@testable import Skwad

/// Tests for the helper functions and computed properties used in DiffView
/// These test the pure logic extracted from the view code
@Suite("DiffView Helpers")
struct DiffViewHelpersTests {

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

    @Suite("Background Color")
    struct BackgroundColorTests {

        @Test("addition has green background")
        func additionHasGreenBackground() {
            let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .addition)
            #expect(color == "green")
            #expect(opacity == 0.2)
        }

        @Test("deletion has red background")
        func deletionHasRedBackground() {
            let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .deletion)
            #expect(color == "red")
            #expect(opacity == 0.2)
        }

        @Test("hunkHeader has blue background")
        func hunkHeaderHasBlueBackground() {
            let (color, opacity) = DiffViewHelpersTests.backgroundColor(for: .hunkHeader)
            #expect(color == "blue")
            #expect(opacity == 0.15)
        }

        @Test("context has clear background")
        func contextHasClearBackground() {
            let (color, _) = DiffViewHelpersTests.backgroundColor(for: .context)
            #expect(color == "clear")
        }

        @Test("header has clear background")
        func headerHasClearBackground() {
            let (color, _) = DiffViewHelpersTests.backgroundColor(for: .header)
            #expect(color == "clear")
        }
    }

    // MARK: - Text Color Tests

    @Suite("Text Color")
    struct TextColorTests {

        @Test("addition has green text")
        func additionHasGreenText() {
            let color = DiffViewHelpersTests.textColor(for: .addition)
            #expect(color == "green")
        }

        @Test("deletion has red text")
        func deletionHasRedText() {
            let color = DiffViewHelpersTests.textColor(for: .deletion)
            #expect(color == "red")
        }

        @Test("hunkHeader has blue text")
        func hunkHeaderHasBlueText() {
            let color = DiffViewHelpersTests.textColor(for: .hunkHeader)
            #expect(color == "blue")
        }

        @Test("context has primary text")
        func contextHasPrimaryText() {
            let color = DiffViewHelpersTests.textColor(for: .context)
            #expect(color == "primary")
        }

        @Test("header has primary text")
        func headerHasPrimaryText() {
            let color = DiffViewHelpersTests.textColor(for: .header)
            #expect(color == "primary")
        }
    }

    // MARK: - Prefix Mapping Tests

    @Suite("Prefix Mapping")
    struct PrefixMappingTests {

        @Test("addition has plus prefix")
        func additionHasPlusPrefix() {
            let prefix = DiffViewHelpersTests.prefix(for: .addition)
            #expect(prefix == "+")
        }

        @Test("deletion has minus prefix")
        func deletionHasMinusPrefix() {
            let prefix = DiffViewHelpersTests.prefix(for: .deletion)
            #expect(prefix == "-")
        }

        @Test("context has space prefix")
        func contextHasSpacePrefix() {
            let prefix = DiffViewHelpersTests.prefix(for: .context)
            #expect(prefix == " ")
        }

        @Test("hunkHeader has empty prefix")
        func hunkHeaderHasEmptyPrefix() {
            let prefix = DiffViewHelpersTests.prefix(for: .hunkHeader)
            #expect(prefix == "")
        }

        @Test("header has empty prefix")
        func headerHasEmptyPrefix() {
            let prefix = DiffViewHelpersTests.prefix(for: .header)
            #expect(prefix == "")
        }
    }

    // MARK: - DiffLine Tests

    @Suite("DiffLine")
    struct DiffLineTests {

        @Test("addition line has newLineNumber but no oldLineNumber")
        func additionLineNumbers() {
            let line = DiffLine(
                kind: .addition,
                content: "new line",
                oldLineNumber: nil,
                newLineNumber: 5
            )

            #expect(line.oldLineNumber == nil)
            #expect(line.newLineNumber == 5)
        }

        @Test("deletion line has oldLineNumber but no newLineNumber")
        func deletionLineNumbers() {
            let line = DiffLine(
                kind: .deletion,
                content: "removed line",
                oldLineNumber: 3,
                newLineNumber: nil
            )

            #expect(line.oldLineNumber == 3)
            #expect(line.newLineNumber == nil)
        }

        @Test("context line has both line numbers")
        func contextLineNumbers() {
            let line = DiffLine(
                kind: .context,
                content: "unchanged line",
                oldLineNumber: 10,
                newLineNumber: 12
            )

            #expect(line.oldLineNumber == 10)
            #expect(line.newLineNumber == 12)
        }
    }

    // MARK: - FileDiff Tests

    @Suite("FileDiff")
    struct FileDiffTests {

        @Test("additions computed property counts addition lines")
        func additionsCountsCorrectly() {
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

            #expect(diff.additions == 2)
        }

        @Test("deletions computed property counts deletion lines")
        func deletionsCountsCorrectly() {
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

            #expect(diff.deletions == 3)
        }

        @Test("binary file has no hunks")
        func binaryFileHasNoHunks() {
            let diff = FileDiff(
                path: "image.png",
                oldPath: nil,
                isBinary: true,
                hunks: []
            )

            #expect(diff.isBinary == true)
            #expect(diff.hunks.isEmpty)
            #expect(diff.additions == 0)
            #expect(diff.deletions == 0)
        }
    }
}
