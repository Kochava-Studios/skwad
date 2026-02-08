import Foundation

/// High-level git repository operations
class GitRepository {
    let path: String
    private let cli = GitCLI.shared

    init(path: String) {
        self.path = path
    }

    // MARK: - Status

    /// Get full repository status
    func status() -> RepositoryStatus {
        let result = cli.run(["status", "--porcelain=v2", "--branch"], in: path)

        guard case .success(let output) = result else {
            return RepositoryStatus(branch: nil, upstream: nil, ahead: 0, behind: 0, files: [])
        }

        return GitOutputParser.parseStatus(output)
    }

    /// Check if working tree is clean
    func isClean() -> Bool {
        let result = cli.run(["status", "--porcelain"], in: path)
        guard case .success(let output) = result else { return false }
        return output.isEmpty
    }

    // MARK: - Diff

    /// Get diff for files (all or specific file)
    /// - Parameters:
    ///   - file: Specific file path, or nil for all files
    ///   - staged: If true, show staged changes; if false, show unstaged
    func diff(for file: String? = nil, staged: Bool = false) -> [FileDiff] {
        var args = ["diff", "--no-color"]
        if staged {
            args.append("--staged")
        }
        if let file = file {
            args.append("--")
            args.append(file)
        }

        let result = cli.run(args, in: path)
        guard case .success(let output) = result, !output.isEmpty else {
            return []
        }

        return GitOutputParser.parseDiff(output)
    }

    /// Get combined diff statistics (unstaged + staged) in minimal git calls
    func combinedDiffStats() -> GitLineStats {
        // One call for unstaged, one for staged
        let unstagedResult = cli.run(["diff", "--numstat"], in: path)
        let stagedResult = cli.run(["diff", "--staged", "--numstat"], in: path)

        var insertions = 0, deletions = 0, files = 0

        if case .success(let output) = unstagedResult {
            let s = GitOutputParser.parseNumstat(output)
            insertions += s.insertions; deletions += s.deletions; files += s.files
        }
        if case .success(let output) = stagedResult {
            let s = GitOutputParser.parseNumstat(output)
            insertions += s.insertions; deletions += s.deletions; files += s.files
        }

        // Untracked files: count via status (already one call)
        let untrackedFiles = status().untrackedFiles
        for file in untrackedFiles {
            let r = cli.run(["diff", "--numstat", "--no-index", "--", "/dev/null", file.path], in: path)
            if case .success(let output) = r {
                let s = GitOutputParser.parseNumstat(output)
                insertions += s.insertions; deletions += s.deletions; files += s.files
            }
        }

        return GitLineStats(insertions: insertions, deletions: deletions, files: files)
    }

    // MARK: - Staging

    /// Stage files for commit
    func stage(_ paths: [String]) throws {
        guard !paths.isEmpty else { return }
        let args = ["add"] + paths
        let result = cli.run(args, in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Unstage files (remove from index but keep changes)
    func unstage(_ paths: [String]) throws {
        guard !paths.isEmpty else { return }
        let args = ["restore", "--staged"] + paths
        let result = cli.run(args, in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Stage all changes
    func stageAll() throws {
        let result = cli.run(["add", "-A"], in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Unstage all files
    func unstageAll() throws {
        let result = cli.run(["reset", "HEAD"], in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Discard changes in working directory for specific files
    func discardChanges(_ paths: [String]) throws {
        guard !paths.isEmpty else { return }
        let args = ["restore"] + paths
        let result = cli.run(args, in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    // MARK: - Commit

    /// Create a commit with the given message
    func commit(message: String) throws {
        let result = cli.run(["commit", "-m", message], in: path)
        if case .failure(let error) = result {
            throw error
        }
    }

    // MARK: - Branch Info

    /// Get current branch name
    func currentBranch() -> String? {
        let result = cli.run(["branch", "--show-current"], in: path)
        guard case .success(let output) = result, !output.isEmpty else {
            return nil
        }
        return output
    }

    /// Check if there are unpushed commits
    func hasUnpushedCommits() -> Bool {
        let result = cli.run(["log", "@{u}..", "--oneline"], in: path)
        guard case .success(let output) = result else {
            return false
        }
        return !output.isEmpty
    }

    /// Get ahead/behind count relative to upstream
    func aheadBehind() -> (ahead: Int, behind: Int) {
        let result = cli.run(["rev-list", "--left-right", "--count", "@{u}...HEAD"], in: path)
        guard case .success(let output) = result else {
            return (0, 0)
        }

        let parts = output.split(separator: "\t")
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return (0, 0)
        }

        return (ahead, behind)
    }
}

