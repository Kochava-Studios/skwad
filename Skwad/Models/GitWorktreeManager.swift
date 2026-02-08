import Foundation

/// Information about a git repository
struct RepoInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let worktrees: [WorktreeInfo]

    /// Path to the main clone folder (first worktree)
    var path: String { worktrees.first?.path ?? "" }
}

/// Information about a git worktree
struct WorktreeInfo: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
}

/// Git worktree write operations
class GitWorktreeManager {
    static let shared = GitWorktreeManager()

    private let cli = GitCLI.shared

    private init() {}

    /// Check if a path is a git repository (either main repo or worktree)
    func isGitRepo(_ path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }

    /// Create a new worktree with a new branch
    func createWorktree(
        repoPath: String,
        branchName: String,
        destinationPath: String
    ) throws {
        let args = ["worktree", "add", "-b", branchName, destinationPath]
        let result = cli.run(args, in: repoPath)

        if case .failure(let error) = result {
            throw error
        }
    }

    /// Get suggested worktree path for a new branch
    func suggestedWorktreePath(repoPath: String, branchName: String) -> String {
        let repoName = (repoPath as NSString).lastPathComponent
        let parentPath = (repoPath as NSString).deletingLastPathComponent
        let sanitizedBranch = branchName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return (parentPath as NSString).appendingPathComponent("\(repoName)-\(sanitizedBranch)")
    }
}
