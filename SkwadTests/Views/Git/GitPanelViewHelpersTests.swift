import XCTest
import SwiftUI
@testable import Skwad

final class GitPanelViewHelpersTests: XCTestCase {

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
}
