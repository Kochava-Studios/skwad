import XCTest
import Foundation
@testable import Skwad

final class GitWorktreeManagerTests: XCTestCase {

    // MARK: - Suggested Worktree Path

    func testAppendsSanitizedBranchToRepoName() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/Users/test/src/my-repo",
            branchName: "feature"
        )
        XCTAssertEqual(result, "/Users/test/src/my-repo-feature")
    }

    func testReplacesSlashesWithDashes() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/Users/test/src/my-repo",
            branchName: "feature/new-feature"
        )
        XCTAssertEqual(result, "/Users/test/src/my-repo-feature-new-feature")
    }

    func testReplacesSpacesWithDashes() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/Users/test/src/my-repo",
            branchName: "my new branch"
        )
        XCTAssertEqual(result, "/Users/test/src/my-repo-my-new-branch")
    }

    func testHandlesDeepNestedBranchNames() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/Users/test/src/my-repo",
            branchName: "feature/team/project/task"
        )
        XCTAssertEqual(result, "/Users/test/src/my-repo-feature-team-project-task")
    }

    func testPlacesInParentDirectory() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/Users/test/src/my-repo",
            branchName: "dev"
        )
        XCTAssertTrue(result.hasPrefix("/Users/test/src/"))
        XCTAssertFalse(result.contains("/my-repo/"))
    }

    func testHandlesSimpleBranchName() {
        let manager = GitWorktreeManager.shared
        let result = manager.suggestedWorktreePath(
            repoPath: "/path/to/repo",
            branchName: "main"
        )
        XCTAssertEqual(result, "/path/to/repo-main")
    }

    // MARK: - isGitRepo

    func testReturnsTrueForExistingGitRepo() {
        let manager = GitWorktreeManager.shared
        let currentDir = FileManager.default.currentDirectoryPath

        if FileManager.default.fileExists(atPath: (currentDir as NSString).appendingPathComponent(".git")) {
            XCTAssertTrue(manager.isGitRepo(currentDir))
        }
    }

    func testReturnsFalseForNonGitDirectory() {
        let manager = GitWorktreeManager.shared
        XCTAssertFalse(manager.isGitRepo("/tmp"))
    }

    func testReturnsFalseForNonExistentPath() {
        let manager = GitWorktreeManager.shared
        XCTAssertFalse(manager.isGitRepo("/this/path/does/not/exist"))
    }

    // MARK: - WorktreeInfo

    func testIdIsPath() {
        let info = WorktreeInfo(name: "repo", path: "/unique/path")
        XCTAssertEqual(info.id, "/unique/path")
    }

    // MARK: - RepoInfo

    func testRepoInfoIdIsName() {
        let info = RepoInfo(name: "repo", worktrees: [])
        XCTAssertEqual(info.id, "repo")
    }

    func testRepoInfoPathIsFirstWorktreePath() {
        let info = RepoInfo(name: "repo", worktrees: [
            WorktreeInfo(name: "main", path: "/src/repo"),
            WorktreeInfo(name: "feature", path: "/src/repo-feature"),
        ])
        XCTAssertEqual(info.path, "/src/repo")
    }
}
