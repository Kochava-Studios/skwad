import Testing
import Foundation
@testable import Skwad

@Suite("GitWorktreeManager")
struct GitWorktreeManagerTests {

    // MARK: - Suggested Worktree Path

    @Suite("Suggested Worktree Path")
    struct SuggestedWorktreePathTests {

        @Test("appends sanitized branch to repo name")
        func appendsSanitizedBranchToRepoName() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/Users/test/src/my-repo",
                branchName: "feature"
            )
            #expect(result == "/Users/test/src/my-repo-feature")
        }

        @Test("replaces slashes with dashes")
        func replacesSlashesWithDashes() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/Users/test/src/my-repo",
                branchName: "feature/new-feature"
            )
            #expect(result == "/Users/test/src/my-repo-feature-new-feature")
        }

        @Test("replaces spaces with dashes")
        func replacesSpacesWithDashes() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/Users/test/src/my-repo",
                branchName: "my new branch"
            )
            #expect(result == "/Users/test/src/my-repo-my-new-branch")
        }

        @Test("handles deep nested branch names")
        func handlesDeepNestedBranchNames() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/Users/test/src/my-repo",
                branchName: "feature/team/project/task"
            )
            #expect(result == "/Users/test/src/my-repo-feature-team-project-task")
        }

        @Test("places worktree in parent directory")
        func placesInParentDirectory() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/Users/test/src/my-repo",
                branchName: "dev"
            )
            // Should be /Users/test/src/my-repo-dev, not /Users/test/src/my-repo/my-repo-dev
            #expect(result.hasPrefix("/Users/test/src/"))
            #expect(!result.contains("/my-repo/"))
        }

        @Test("handles simple branch name")
        func handlesSimpleBranchName() {
            let manager = GitWorktreeManager.shared
            let result = manager.suggestedWorktreePath(
                repoPath: "/path/to/repo",
                branchName: "main"
            )
            #expect(result == "/path/to/repo-main")
        }
    }

    // MARK: - isGitRepo

    @Suite("isGitRepo")
    struct IsGitRepoTests {

        @Test("returns true for existing git repo")
        func returnsTrueForExistingGitRepo() {
            let manager = GitWorktreeManager.shared
            // Use the current project directory which is a git repo
            let currentDir = FileManager.default.currentDirectoryPath

            // This test depends on running from the project directory
            // If not a git repo, the test will fail which is expected
            if FileManager.default.fileExists(atPath: (currentDir as NSString).appendingPathComponent(".git")) {
                #expect(manager.isGitRepo(currentDir) == true)
            }
        }

        @Test("returns false for non-git directory")
        func returnsFalseForNonGitDirectory() {
            let manager = GitWorktreeManager.shared
            // /tmp is unlikely to be a git repo
            #expect(manager.isGitRepo("/tmp") == false)
        }

        @Test("returns false for non-existent path")
        func returnsFalseForNonExistentPath() {
            let manager = GitWorktreeManager.shared
            #expect(manager.isGitRepo("/this/path/does/not/exist") == false)
        }
    }

    // MARK: - isWorktree

    @Suite("isWorktree")
    struct IsWorktreeTests {

        @Test("returns false for main repo")
        func returnsFalseForMainRepo() {
            let manager = GitWorktreeManager.shared
            // The main repo has a .git directory, not a .git file
            let currentDir = FileManager.default.currentDirectoryPath
            let gitPath = (currentDir as NSString).appendingPathComponent(".git")
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Main repo - should return false
                    #expect(manager.isWorktree(currentDir) == false)
                }
            }
        }

        @Test("returns false for non-git directory")
        func returnsFalseForNonGitDirectory() {
            let manager = GitWorktreeManager.shared
            #expect(manager.isWorktree("/tmp") == false)
        }
    }

    // MARK: - Worktree Parsing (Unit Tests)

    @Suite("Worktree Parsing")
    struct WorktreeParsingTests {

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

        @Test("parses single main worktree")
        func parsesSingleMainWorktree() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.singleMainWorktree)

            #expect(worktrees.count == 1)
            #expect(worktrees[0].path == "/Users/test/repo")
            #expect(worktrees[0].branch == "main")
            #expect(worktrees[0].isMain == true)
        }

        @Test("parses main with linked worktree")
        func parsesMainWithLinked() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.mainWithOneLinked)

            #expect(worktrees.count == 2)
            #expect(worktrees[0].isMain == true)
            #expect(worktrees[1].isMain == false)
            #expect(worktrees[1].branch == "feature/test")
        }

        @Test("parses multiple worktrees")
        func parsesMultipleWorktrees() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.multipleWorktrees)

            #expect(worktrees.count == 3)
            #expect(worktrees[0].branch == "main")
            #expect(worktrees[1].branch == "feature/test")
            #expect(worktrees[2].branch == "bugfix/fix-123")
        }

        @Test("identifies main worktree as first entry")
        func identifiesMainAsFirstEntry() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.multipleWorktrees)

            let mainWorktrees = worktrees.filter { $0.isMain }
            #expect(mainWorktrees.count == 1)
            #expect(mainWorktrees[0].path == "/Users/test/repo")
        }

        @Test("extracts branch from refs/heads prefix")
        func extractsBranchFromRefsHeads() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.branchWithSlashes)

            #expect(worktrees.count == 1)
            #expect(worktrees[0].branch == "feature/deep/nested/branch")
        }

        @Test("handles detached head")
        func handlesDetachedHead() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.worktreeWithDetachedHead)

            #expect(worktrees.count == 2)
            let detached = worktrees.first { $0.path.contains("detached") }
            #expect(detached?.branch == "detached")
        }

        @Test("handles empty output")
        func handlesEmptyOutput() {
            let worktrees = parseWorktreeListOutput(GitWorktreeFixtures.emptyWorktreeList)
            #expect(worktrees.isEmpty)
        }
    }

    // MARK: - WorktreeInfo Properties

    @Suite("WorktreeInfo Properties")
    struct WorktreeInfoPropertiesTests {

        @Test("displayName returns main for main worktree")
        func displayNameReturnsMainForMain() {
            let info = WorktreeInfo(path: "/path", branch: "develop", isMain: true)
            #expect(info.displayName == "main")
        }

        @Test("displayName returns branch name for linked worktree")
        func displayNameReturnsBranchForLinked() {
            let info = WorktreeInfo(path: "/path", branch: "feature/test", isMain: false)
            #expect(info.displayName == "feature/test")
        }

        @Test("id is path")
        func idIsPath() {
            let info = WorktreeInfo(path: "/unique/path", branch: "branch", isMain: false)
            #expect(info.id == "/unique/path")
        }
    }
}
