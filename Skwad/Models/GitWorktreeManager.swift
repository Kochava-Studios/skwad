import Foundation

/// Information about a git repository
struct RepoInfo: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let worktreeCount: Int
}

/// Information about a git worktree
struct WorktreeInfo: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let branch: String
    let isMain: Bool  // Is this the main worktree (bare repo or first worktree)?

    var displayName: String {
        isMain ? "main" : branch
    }
}

/// Manager for git worktree operations
class GitWorktreeManager {
    static let shared = GitWorktreeManager()

    private let cli = GitCLI.shared

    private init() {}

    // MARK: - Repository Discovery

    /// Discover all git repositories in the given base folder
    /// A repo is identified by having a .git directory (not a .git file, which indicates a worktree)
    func discoverRepos(in baseFolder: String) -> [RepoInfo] {
        return discoverReposWithWorktrees(in: baseFolder).map { $0.repo }
    }

    /// Discover all git repositories and their worktrees in the given base folder
    /// A repo is identified by having a .git directory (not a .git file, which indicates a worktree)
    func discoverReposWithWorktrees(in baseFolder: String) -> [(repo: RepoInfo, worktrees: [WorktreeInfo])] {
        let expandedPath = NSString(string: baseFolder).expandingTildeInPath
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: expandedPath) else {
            return []
        }

        var reposWithWorktrees: [(repo: RepoInfo, worktrees: [WorktreeInfo])] = []

        for item in contents {
            let itemPath = (expandedPath as NSString).appendingPathComponent(item)
            let gitPath = (itemPath as NSString).appendingPathComponent(".git")

            // Check if .git is a directory (main repo) not a file (worktree)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: gitPath, isDirectory: &isDirectory), isDirectory.boolValue {
                let worktrees = listWorktrees(for: itemPath)
                let repo = RepoInfo(
                    name: item,
                    path: itemPath,
                    worktreeCount: worktrees.count
                )
                reposWithWorktrees.append((repo: repo, worktrees: worktrees))
            }
        }

        return reposWithWorktrees.sorted { $0.repo.name.lowercased() < $1.repo.name.lowercased() }
    }

    /// Check if a path is a git worktree (has .git as a file pointing to parent repo)
    func isWorktree(_ path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
            return !isDirectory.boolValue  // .git is a file = worktree
        }
        return false
    }

    /// Check if a path is a git repository (either main repo or worktree)
    func isGitRepo(_ path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitPath)
    }

    // MARK: - Worktree Operations

    /// List all worktrees for a repository
    func listWorktrees(for repoPath: String) -> [WorktreeInfo] {
        let result = cli.runRaw(["worktree", "list", "--porcelain"], in: repoPath)
        guard result.isSuccess else { return [] }

        var worktrees: [WorktreeInfo] = []
        var currentPath: String?
        var currentBranch: String?
        var isFirst = true

        for line in result.output.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                // Save previous worktree if we have one
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
                // Extract branch name from refs/heads/branch-name
                if fullBranch.hasPrefix("refs/heads/") {
                    currentBranch = String(fullBranch.dropFirst("refs/heads/".count))
                } else {
                    currentBranch = fullBranch
                }
            } else if line.hasPrefix("detached") {
                currentBranch = "detached"
            }
        }

        // Don't forget the last one
        if let path = currentPath {
            worktrees.append(WorktreeInfo(
                path: path,
                branch: currentBranch ?? "detached",
                isMain: isFirst
            ))
        }

        return worktrees
    }

    /// List remote branches for a repository
    func listRemoteBranches(for repoPath: String) -> [String] {
        let result = cli.runRaw(["branch", "-r", "--format=%(refname:short)"], in: repoPath)
        guard result.isSuccess else { return [] }

        return result.output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("HEAD") }
            .map { branch in
                // Remove origin/ prefix for display
                if branch.hasPrefix("origin/") {
                    return String(branch.dropFirst("origin/".count))
                }
                return branch
            }
            .sorted()
    }

    /// List local branches for a repository
    func listLocalBranches(for repoPath: String) -> [String] {
        let result = cli.runRaw(["branch", "--format=%(refname:short)"], in: repoPath)
        guard result.isSuccess else { return [] }

        return result.output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// Fetch from remote (to get latest branches)
    func fetchRemote(for repoPath: String) async throws {
        let result = await cli.runAsync(["fetch", "--prune"], in: repoPath)
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Create a new worktree
    /// - Parameters:
    ///   - repoPath: Path to the main repository
    ///   - branchName: Name of the branch to checkout or create
    ///   - destinationPath: Where to create the worktree
    ///   - createBranch: If true, creates a new branch; if false, checks out existing branch
    func createWorktree(
        repoPath: String,
        branchName: String,
        destinationPath: String,
        createBranch: Bool
    ) throws {
        var args = ["worktree", "add"]

        if createBranch {
            args.append(contentsOf: ["-b", branchName, destinationPath])
        } else {
            args.append(contentsOf: [destinationPath, branchName])
        }

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
