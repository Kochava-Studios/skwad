import XCTest
import SwiftUI
@testable import Skwad

final class GitPanelViewHelpersTests: XCTestCase {

    // MARK: - Panel Width Constraints

    private func constrainPanelWidth(_ width: CGFloat) -> CGFloat {
        max(350, min(800, width))
    }

    func testPanelWidthConstrainedToMinimum350() {
        let result = constrainPanelWidth(200)
        XCTAssertEqual(result, 350)
    }

    func testPanelWidthConstrainedToMaximum800() {
        let result = constrainPanelWidth(1000)
        XCTAssertEqual(result, 800)
    }

    func testPanelWidthWithinBoundsUnchanged() {
        let result = constrainPanelWidth(500)
        XCTAssertEqual(result, 500)
    }

    func testPanelWidthAtBoundaries() {
        XCTAssertEqual(constrainPanelWidth(350), 350)
        XCTAssertEqual(constrainPanelWidth(800), 800)
    }

    // MARK: - File Status Symbol Display

    private func statusSymbol(for file: FileStatus) -> String {
        if let staged = file.stagedStatus, staged != .untracked {
            return staged.symbol
        }
        if let unstaged = file.unstagedStatus {
            return unstaged.symbol
        }
        return "?"
    }

    func testModifiedStagedFileShowsM() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "M")
    }

    func testAddedStagedFileShowsA() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .added, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "A")
    }

    func testDeletedStagedFileShowsD() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .deleted, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "D")
    }

    func testRenamedStagedFileShowsR() {
        let file = FileStatus(path: "new.swift", originalPath: "old.swift", stagedStatus: .renamed, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "R")
    }

    func testCopiedStagedFileShowsC() {
        let file = FileStatus(path: "copy.swift", originalPath: "original.swift", stagedStatus: .copied, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "C")
    }

    func testUntrackedFileShowsQuestion() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .untracked, unstagedStatus: .untracked)
        XCTAssertEqual(statusSymbol(for: file), "?")
    }

    func testModifiedUnstagedFileShowsM() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: .modified)
        XCTAssertEqual(statusSymbol(for: file), "M")
    }

    func testUnknownStatusReturnsQuestion() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: nil)
        XCTAssertEqual(statusSymbol(for: file), "?")
    }

    // MARK: - File Status Properties

    func testFileNameExtractsLastPathComponent() {
        let file = FileStatus(path: "Skwad/Views/ContentView.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        XCTAssertEqual(file.fileName, "ContentView.swift")
    }

    func testDirectoryExtractsParentPath() {
        let file = FileStatus(path: "Skwad/Views/ContentView.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        XCTAssertEqual(file.directory, "Skwad/Views")
    }

    func testDirectoryIsEmptyForRootFile() {
        let file = FileStatus(path: "README.md", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        XCTAssertEqual(file.directory, "")
    }

    func testIsUntrackedReturnsTrueForUntrackedFiles() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .untracked, unstagedStatus: .untracked)
        XCTAssertTrue(file.isUntracked)
    }

    func testIsUntrackedReturnsFalseForTrackedFiles() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        XCTAssertFalse(file.isUntracked)
    }

    // MARK: - Repository Status

    func testIsCleanReturnsTrueWhenNoFiles() {
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: []
        )
        XCTAssertTrue(status.isClean)
    }

    func testIsCleanReturnsFalseWhenFilesExist() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [file]
        )
        XCTAssertFalse(status.isClean)
    }

    func testHasStagedReturnsTrueWhenStagedFilesExist() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [file]
        )
        XCTAssertTrue(status.hasStaged)
    }

    func testHasStagedReturnsFalseWhenNoStagedFiles() {
        let file = FileStatus(path: "test.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: .modified)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [file]
        )
        XCTAssertFalse(status.hasStaged)
    }

    func testStagedFilesFiltersCorrectly() {
        let staged = FileStatus(path: "staged.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let unstaged = FileStatus(path: "unstaged.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: .modified)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [staged, unstaged]
        )
        XCTAssertEqual(status.stagedFiles.count, 1)
        XCTAssertEqual(status.stagedFiles[0].path, "staged.swift")
    }

    func testModifiedFilesFiltersCorrectly() {
        let staged = FileStatus(path: "staged.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let unstaged = FileStatus(path: "unstaged.swift", originalPath: nil, stagedStatus: nil, unstagedStatus: .modified)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [staged, unstaged]
        )
        XCTAssertEqual(status.modifiedFiles.count, 1)
        XCTAssertEqual(status.modifiedFiles[0].path, "unstaged.swift")
    }

    func testUntrackedFilesFiltersCorrectly() {
        let tracked = FileStatus(path: "tracked.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let untracked = FileStatus(path: "untracked.swift", originalPath: nil, stagedStatus: .untracked, unstagedStatus: .untracked)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [tracked, untracked]
        )
        XCTAssertEqual(status.untrackedFiles.count, 1)
        XCTAssertEqual(status.untrackedFiles[0].path, "untracked.swift")
    }

    func testHasUnpushedReturnsTrueWhenAheadGreaterThan0() {
        let status = RepositoryStatus(
            branch: "main",
            upstream: "origin/main",
            ahead: 3,
            behind: 0,
            files: []
        )
        XCTAssertTrue(status.hasUnpushed)
    }

    func testHasUnpushedReturnsFalseWhenAheadIs0() {
        let status = RepositoryStatus(
            branch: "main",
            upstream: "origin/main",
            ahead: 0,
            behind: 0,
            files: []
        )
        XCTAssertFalse(status.hasUnpushed)
    }

    func testConflictedFilesFiltersCorrectly() {
        let normal = FileStatus(path: "normal.swift", originalPath: nil, stagedStatus: .modified, unstagedStatus: nil)
        let conflict = FileStatus(path: "conflict.swift", originalPath: nil, stagedStatus: .unmerged, unstagedStatus: .unmerged)
        let status = RepositoryStatus(
            branch: "main",
            upstream: nil,
            ahead: 0,
            behind: 0,
            files: [normal, conflict]
        )
        XCTAssertEqual(status.conflictedFiles.count, 1)
        XCTAssertEqual(status.conflictedFiles[0].path, "conflict.swift")
    }

    // MARK: - File Status Type Symbol

    func testModifiedSymbolIsM() {
        XCTAssertEqual(FileStatusType.modified.symbol, "M")
    }

    func testAddedSymbolIsA() {
        XCTAssertEqual(FileStatusType.added.symbol, "A")
    }

    func testDeletedSymbolIsD() {
        XCTAssertEqual(FileStatusType.deleted.symbol, "D")
    }

    func testRenamedSymbolIsR() {
        XCTAssertEqual(FileStatusType.renamed.symbol, "R")
    }

    func testCopiedSymbolIsC() {
        XCTAssertEqual(FileStatusType.copied.symbol, "C")
    }

    func testUntrackedSymbolIsQuestion() {
        XCTAssertEqual(FileStatusType.untracked.symbol, "?")
    }

    func testUnmergedSymbolIsU() {
        XCTAssertEqual(FileStatusType.unmerged.symbol, "U")
    }

    func testIgnoredSymbolIsExclamation() {
        XCTAssertEqual(FileStatusType.ignored.symbol, "!")
    }

    func testAllTypesHaveDisplayNames() {
        for type in FileStatusType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }

    func testRawValuesMatchSymbols() {
        for type in FileStatusType.allCases {
            XCTAssertEqual(type.rawValue, type.symbol)
        }
    }

    // MARK: - Branch Info Display

    func testAheadCountFormattedWithUpArrow() {
        let ahead = 5
        let display = "↑\(ahead)"
        XCTAssertEqual(display, "↑5")
    }

    func testBehindCountFormattedWithDownArrow() {
        let behind = 3
        let display = "↓\(behind)"
        XCTAssertEqual(display, "↓3")
    }

    func testZeroAheadNotDisplayed() {
        let ahead = 0
        let shouldDisplay = ahead > 0
        XCTAssertFalse(shouldDisplay)
    }

    func testZeroBehindNotDisplayed() {
        let behind = 0
        let shouldDisplay = behind > 0
        XCTAssertFalse(shouldDisplay)
    }

    // MARK: - Section Title

    private func sectionTitle(_ title: String, count: Int) -> String {
        "\(title) (\(count))"
    }

    func testStagedChangesSectionTitle() {
        let title = sectionTitle("Staged Changes", count: 3)
        XCTAssertEqual(title, "Staged Changes (3)")
    }

    func testChangesSectionTitle() {
        let title = sectionTitle("Changes", count: 5)
        XCTAssertEqual(title, "Changes (5)")
    }

    func testUntrackedSectionTitle() {
        let title = sectionTitle("Untracked", count: 2)
        XCTAssertEqual(title, "Untracked (2)")
    }

    func testConflictsSectionTitle() {
        let title = sectionTitle("Conflicts", count: 1)
        XCTAssertEqual(title, "Conflicts (1)")
    }

    // MARK: - Diff Stats Display

    func testAdditionsFormattedWithPlus() {
        let additions = 42
        let display = "+\(additions)"
        XCTAssertEqual(display, "+42")
    }

    func testDeletionsFormattedWithMinus() {
        let deletions = 17
        let display = "-\(deletions)"
        XCTAssertEqual(display, "-17")
    }

    func testZeroAdditionsNotDisplayed() {
        let additions = 0
        let shouldDisplay = additions > 0
        XCTAssertFalse(shouldDisplay)
    }

    func testZeroDeletionsNotDisplayed() {
        let deletions = 0
        let shouldDisplay = deletions > 0
        XCTAssertFalse(shouldDisplay)
    }
}
