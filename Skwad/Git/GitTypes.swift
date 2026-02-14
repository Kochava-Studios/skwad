import Foundation

// MARK: - File Status

/// Type of change for a file in git
enum FileStatusType: String, CaseIterable {
    case untracked = "?"
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case unmerged = "U"
    case ignored = "!"

    var displayName: String {
        switch self {
        case .untracked: return "Untracked"
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .unmerged: return "Unmerged"
        case .ignored: return "Ignored"
        }
    }

    var symbol: String {
        switch self {
        case .untracked: return "?"
        case .modified: return "M"
        case .added: return "A"
        case .deleted: return "D"
        case .renamed: return "R"
        case .copied: return "C"
        case .unmerged: return "U"
        case .ignored: return "!"
        }
    }
}

/// Status of a single file in the repository
struct FileStatus: Identifiable, Hashable {
    var id: String { path }

    let path: String
    let originalPath: String?  // For renamed/copied files
    let stagedStatus: FileStatusType?
    let unstagedStatus: FileStatusType?

    /// File has staged changes
    var isStaged: Bool {
        stagedStatus != nil && stagedStatus != .untracked
    }

    /// File has unstaged changes (modified in working tree)
    var hasUnstagedChanges: Bool {
        unstagedStatus != nil && unstagedStatus != .untracked
    }

    /// File is untracked
    var isUntracked: Bool {
        stagedStatus == .untracked || unstagedStatus == .untracked
    }

    /// File has merge conflicts
    var hasConflicts: Bool {
        stagedStatus == .unmerged || unstagedStatus == .unmerged
    }

    /// Display name (filename without path)
    var fileName: String {
        (path as NSString).lastPathComponent
    }

    /// Directory containing the file
    var directory: String {
        let dir = (path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }
}

// MARK: - Diff Types

/// A single line in a diff
struct DiffLine: Identifiable, Hashable {
    let id = UUID()

    enum Kind: Hashable {
        case context
        case addition
        case deletion
        case header
        case hunkHeader

        var prefix: String {
            switch self {
            case .addition: return "+"
            case .deletion: return "-"
            case .hunkHeader, .header: return ""
            case .context: return " "
            }
        }
    }

    let kind: Kind
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

/// A hunk (section) of changes in a diff
struct DiffHunk: Identifiable, Hashable {
    let id = UUID()

    let header: String  // e.g., "@@ -10,5 +10,7 @@"
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]
}

/// Diff for a single file
struct FileDiff: Identifiable, Hashable {
    var id: String { path }

    let path: String
    let oldPath: String?  // For renamed files
    let isBinary: Bool
    let hunks: [DiffHunk]

    /// Total lines added
    var additions: Int {
        hunks.flatMap { $0.lines }.filter { $0.kind == .addition }.count
    }

    /// Total lines deleted
    var deletions: Int {
        hunks.flatMap { $0.lines }.filter { $0.kind == .deletion }.count
    }
}

// MARK: - Repository Status Summary

/// Summary of repository status
struct RepositoryStatus {
    let branch: String?
    let upstream: String?
    let ahead: Int
    let behind: Int
    let files: [FileStatus]

    /// Files that are staged
    var stagedFiles: [FileStatus] {
        files.filter { $0.isStaged }
    }

    /// Files with unstaged modifications
    var modifiedFiles: [FileStatus] {
        files.filter { $0.hasUnstagedChanges && !$0.isUntracked }
    }

    /// Untracked files
    var untrackedFiles: [FileStatus] {
        files.filter { $0.isUntracked }
    }

    /// Files with conflicts
    var conflictedFiles: [FileStatus] {
        files.filter { $0.hasConflicts }
    }

    /// Working tree is clean (no changes)
    var isClean: Bool {
        files.isEmpty
    }

    /// Has any staged changes ready to commit
    var hasStaged: Bool {
        !stagedFiles.isEmpty
    }

    /// Has commits not pushed to upstream
    var hasUnpushed: Bool {
        ahead > 0
    }
}
