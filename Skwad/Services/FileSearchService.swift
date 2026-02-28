import Foundation

/// Result of a file search match
struct FileResult: Identifiable {
    let id = UUID()
    let relativePath: String
    let score: Int
    let matchedIndices: [Int]
}

/// Async file enumeration and fuzzy search service
@Observable
final class FileSearchService {

    var results: [FileResult] = []
    var isLoading = false
    var tooManyFiles = false

    private(set) var cachedFiles: [String] = []
    private var currentFolder: String?

    private static let maxFiles = 50_000
    private static let maxResults = 50
    private static let excludedDirs: Set<String> = [".git", "node_modules", ".build", "__pycache__", ".DS_Store", ".svn", ".hg", "Pods", "DerivedData"]

    // MARK: - Public API

    /// Load files from directory (always refreshes)
    func loadFiles(in folder: String) async {
        await MainActor.run {
            isLoading = true
            tooManyFiles = false
        }

        let (capped, overflow) = await Task.detached {
            let files: [String]
            if GitWorktreeManager.shared.isGitRepo(folder) {
                files = self.enumerateGitFiles(in: folder)
            } else {
                files = self.enumerateFileSystem(in: folder)
            }
            let capped = Array(files.prefix(Self.maxFiles))
            let overflow = files.count > Self.maxFiles
            return (capped, overflow)
        }.value

        await MainActor.run {
            self.cachedFiles = capped
            self.currentFolder = folder
            self.tooManyFiles = overflow
            self.isLoading = false
        }
    }

    /// Search cached files with pattern
    func search(pattern: String) async {
        guard !pattern.isEmpty else {
            await MainActor.run { results = [] }
            return
        }

        let files = cachedFiles
        let scored = files.compactMap { path -> FileResult? in
            guard let match = FuzzyScorer.scoreFile(pattern: pattern, path: path) else { return nil }
            return FileResult(relativePath: path, score: match.score, matchedIndices: match.matchedIndices)
        }
        .sorted { $0.score > $1.score }

        let top = Array(scored.prefix(Self.maxResults))

        await MainActor.run {
            results = top
        }
    }

    /// Clear cache and results
    func reset() {
        cachedFiles = []
        currentFolder = nil
        results = []
        tooManyFiles = false
    }

    /// Set cached files directly (for testing)
    func setCachedFiles(_ files: [String]) {
        cachedFiles = files
    }

    // MARK: - File Enumeration

    private func enumerateGitFiles(in folder: String) -> [String] {
        let result = GitCLI.shared.run(
            ["ls-files", "--cached", "--others", "--exclude-standard"],
            in: folder
        )
        switch result {
        case .success(let output):
            return output.components(separatedBy: "\n").filter { !$0.isEmpty }
        case .failure:
            // Fallback to filesystem enumeration
            return enumerateFileSystem(in: folder)
        }
    }

    private func enumerateFileSystem(in folder: String) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: folder),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [String] = []
        let folderURL = URL(fileURLWithPath: folder)

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent

            // Skip excluded directories
            if Self.excludedDirs.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            // Skip directories
            if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                continue
            }

            let relativePath = url.path.replacingOccurrences(of: folderURL.path + "/", with: "")
            files.append(relativePath)

            if files.count > Self.maxFiles {
                break
            }
        }

        return files
    }
}
