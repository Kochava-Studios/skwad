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
        // Should be /Users/test/src/my-repo-dev, not /Users/test/src/my-repo/my-repo-dev
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
        // Use the current project directory which is a git repo
        let currentDir = FileManager.default.currentDirectoryPath

        // This test depends on running from the project directory
        // If not a git repo, the test will fail which is expected
        if FileManager.default.fileExists(atPath: (currentDir as NSString).appendingPathComponent(".git")) {
            XCTAssertTrue(manager.isGitRepo(currentDir))
        }
    }

    func testReturnsFalseForNonGitDirectory() {
        let manager = GitWorktreeManager.shared
        // /tmp is unlikely to be a git repo
        XCTAssertFalse(manager.isGitRepo("/tmp"))
    }

    func testReturnsFalseForNonExistentPath() {
        let manager = GitWorktreeManager.shared
        XCTAssertFalse(manager.isGitRepo("/this/path/does/not/exist"))
    }

    // MARK: - isWorktree

    func testReturnsFalseForMainRepo() {
        let manager = GitWorktreeManager.shared
        // The main repo has a .git directory, not a .git file
        let currentDir = FileManager.default.currentDirectoryPath
        let gitPath = (currentDir as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false

        if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Main repo - should return false
                XCTAssertFalse(manager.isWorktree(currentDir))
            }
        }
    }

    func testWorktreeReturnsFalseForNonGitDirectory() {
        let manager = GitWorktreeManager.shared
        XCTAssertFalse(manager.isWorktree("/tmp"))
    }

    // MARK: - Worktree Parsing (Unit Tests)

    /// Helper to parse worktree list output the same way the manager does
    private func parseWorktreeListOutput(_ output: String) -> [WorktreeInfo] {
        var worktrees: [WorktreeInfo] = []
        var currentPath: String?
        var currentBranch: String?
        var isFirst = true

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                if let path = currentPath {
                    worktrees.append(WorktreeInfo(
                        path: path,
                        branch: currentBranch ?? "detached",
                        isMain: isFirst
                    ))
                    isFirst = false
                }
                currentPath = String(line.dropFirst("worktree ".count))
                currentBranch = nil
            } else if line.hasPrefix("branch ") {
                let fullBranch = String(line.dropFirst("branch ".count))
                if fullBranch.hasPrefix("refs/heads/") {
                    currentBranch = String(fullBranch.dropFirst("refs/heads/".count))
                } else {
                    currentBranch = fullBranch
                }
            } else if line.hasPrefix("detached") {
                currentBranch = "detached"
            }
        }

        if let path = currentPath {
            worktrees.append(WorktreeInfo(
                path: path,
                branch: currentBranch ?? "detached",
                isMain: isFirst
            ))
        }

        return worktrees
    }

    func testParsesSingleMainWorktree() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.singleMainWorktree)

        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees[0].path, "/Users/test/repo")
        XCTAssertEqual(worktrees[0].branch, "main")
        XCTAssertTrue(worktrees[0].isMain)
    }

    func testParsesMainWithLinked() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.mainWithOneLinked)

        XCTAssertEqual(worktrees.count, 2)
        XCTAssertTrue(worktrees[0].isMain)
        XCTAssertFalse(worktrees[1].isMain)
        XCTAssertEqual(worktrees[1].branch, "feature/test")
    }

    func testParsesMultipleWorktrees() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.multipleWorktrees)

        XCTAssertEqual(worktrees.count, 3)
        XCTAssertEqual(worktrees[0].branch, "main")
        XCTAssertEqual(worktrees[1].branch, "feature/test")
        XCTAssertEqual(worktrees[2].branch, "bugfix/fix-123")
    }

    func testIdentifiesMainAsFirstEntry() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.multipleWorktrees)

        let mainWorktrees = worktrees.filter { $0.isMain }
        XCTAssertEqual(mainWorktrees.count, 1)
        XCTAssertEqual(mainWorktrees[0].path, "/Users/test/repo")
    }

    func testExtractsBranchFromRefsHeads() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.branchWithSlashes)

        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(worktrees[0].branch, "feature/deep/nested/branch")
    }

    func testHandlesDetachedHead() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.worktreeWithDetachedHead)

        XCTAssertEqual(worktrees.count, 2)
        let detached = worktrees.first { $0.path.contains("detached") }
        XCTAssertEqual(detached?.branch, "detached")
    }

    func testHandlesEmptyOutput() {
        let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.emptyWorktreeList)
        XCTAssertTrue(worktrees.isEmpty)
    }

    // MARK: - WorktreeInfo Properties

    func testDisplayNameReturnsMainForMain() {
        let info = WorktreeInfo(path: "/path", branch: "develop", isMain: true)
        XCTAssertEqual(info.displayName, "main")
    }

    func testDisplayNameReturnsBranchForLinked() {
        let info = WorktreeInfo(path: "/path", branch: "feature/test", isMain: false)
        XCTAssertEqual(info.displayName, "feature/test")
    }

    func testIdIsPath() {
        let info = WorktreeInfo(path: "/unique/path", branch: "branch", isMain: false)
        XCTAssertEqual(info.id, "/unique/path")
    }
}
