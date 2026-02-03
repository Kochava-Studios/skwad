import Foundation

/// Test fixtures for git worktree parsing
enum GitWorktreeFixtures {

    // MARK: - Worktree List Porcelain Output

    /// Empty worktree list
    static let emptyWorktreeList = ""

    /// Single main worktree
    static let singleMainWorktree = """
worktree /Users/test/repo
HEAD abc123def456
branch refs/heads/main
"""

    /// Main worktree with one linked worktree
    static let mainWithOneLinked = """
worktree /Users/test/repo
HEAD abc123def456
branch refs/heads/main

worktree /Users/test/repo-feature
HEAD def789ghi012
branch refs/heads/feature/test
"""

    /// Multiple worktrees
    static let multipleWorktrees = """
worktree /Users/test/repo
HEAD abc123def456
branch refs/heads/main

worktree /Users/test/repo-feature
HEAD def789ghi012
branch refs/heads/feature/test

worktree /Users/test/repo-bugfix
HEAD ghi345jkl678
branch refs/heads/bugfix/fix-123
"""

    /// Worktree with detached HEAD
    static let worktreeWithDetachedHead = """
worktree /Users/test/repo
HEAD abc123def456
branch refs/heads/main

worktree /Users/test/repo-detached
HEAD def789ghi012
detached
"""

    /// Branch name with slashes (feature branch)
    static let branchWithSlashes = """
worktree /Users/test/repo
HEAD abc123def456
branch refs/heads/feature/deep/nested/branch
"""

    // MARK: - Branch List Output

    /// Local branches
    static let localBranches = """
main
develop
feature/test
bugfix/fix-123
"""

    /// Remote branches
    static let remoteBranches = """
origin/main
origin/develop
origin/feature/test
origin/HEAD
"""

    // MARK: - Expected Parsed Results

    /// Expected WorktreeInfo for main worktree
    static let expectedMainWorktree = (
        path: "/Users/test/repo",
        branch: "main",
        isMain: true
    )

    /// Expected WorktreeInfo for feature worktree
    static let expectedFeatureWorktree = (
        path: "/Users/test/repo-feature",
        branch: "feature/test",
        isMain: false
    )
}
