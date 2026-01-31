import Foundation

/// Parses git command output into structured data
struct GitOutputParser {
    
    // MARK: - Status Parsing
    
    static func parseStatus(_ output: String) -> RepositoryStatus {
        var branch: String?
        var upstream: String?
        var ahead = 0
        var behind = 0
        var files: [FileStatus] = []
        
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if line.hasPrefix("# branch.upstream ") {
                upstream = String(line.dropFirst("# branch.upstream ".count))
            } else if line.hasPrefix("# branch.ab ") {
                let ab = String(line.dropFirst("# branch.ab ".count))
                let parts = ab.split(separator: " ")
                for part in parts {
                    if part.hasPrefix("+"), let n = Int(part.dropFirst()) {
                        ahead = n
                    } else if part.hasPrefix("-"), let n = Int(part.dropFirst()) {
                        behind = n
                    }
                }
            } else if line.hasPrefix("1 ") || line.hasPrefix("2 ") {
                // Changed entry (1) or renamed/copied entry (2)
                if let status = parseChangedEntry(line) {
                    files.append(status)
                }
            } else if line.hasPrefix("? ") {
                // Untracked file
                let path = String(line.dropFirst("? ".count))
                files.append(FileStatus(
                    path: path,
                    originalPath: nil,
                    stagedStatus: .untracked,
                    unstagedStatus: .untracked
                ))
            } else if line.hasPrefix("u ") {
                // Unmerged entry
                if let status = parseUnmergedEntry(line) {
                    files.append(status)
                }
            }
        }
        
        return RepositoryStatus(
            branch: branch,
            upstream: upstream,
            ahead: ahead,
            behind: behind,
            files: files
        )
    }
    
    private static func parseChangedEntry(_ line: String) -> FileStatus? {
        // Format: 1 XY ... path
        // or:     2 XY ... path\toriginalPath
        let parts = line.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
        guard parts.count >= 9 else { return nil }
        
        let xy = String(parts[1])
        guard xy.count == 2 else { return nil }
        
        let stagedChar = String(xy.prefix(1))
        let unstagedChar = String(xy.suffix(1))
        
        let stagedStatus = parseStatusChar(stagedChar)
        let unstagedStatus = parseStatusChar(unstagedChar)
        
        // Path is the last part, may contain tab for renames
        var pathPart = String(parts[8])
        var originalPath: String?
        
        if line.hasPrefix("2 ") {
            // Renamed/copied: path contains "newPath\toldPath"
            let pathParts = pathPart.split(separator: "\t")
            if pathParts.count == 2 {
                pathPart = String(pathParts[0])
                originalPath = String(pathParts[1])
            }
        }
        
        return FileStatus(
            path: pathPart,
            originalPath: originalPath,
            stagedStatus: stagedStatus,
            unstagedStatus: unstagedStatus
        )
    }
    
    private static func parseUnmergedEntry(_ line: String) -> FileStatus? {
        // Format: u XY ... path
        let parts = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
        guard parts.count >= 11 else { return nil }
        
        let path = String(parts[10])
        
        return FileStatus(
            path: path,
            originalPath: nil,
            stagedStatus: .unmerged,
            unstagedStatus: .unmerged
        )
    }
    
    private static func parseStatusChar(_ char: String) -> FileStatusType? {
        switch char {
        case ".": return nil
        case "M": return .modified
        case "T": return .modified  // Type changed
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "U": return .unmerged
        case "?": return .untracked
        case "!": return .ignored
        default: return nil
        }
    }
    
    // MARK: - Diff Parsing
    
    static func parseDiff(_ output: String) -> [FileDiff] {
        var diffs: [FileDiff] = []
        var currentPath: String?
        var currentOldPath: String?
        var currentHunks: [DiffHunk] = []
        var currentHunkLines: [DiffLine] = []
        var currentHunkHeader: String?
        var currentOldStart = 0
        var currentOldCount = 0
        var currentNewStart = 0
        var currentNewCount = 0
        var oldLineNum = 0
        var newLineNum = 0
        var isBinary = false
        
        func saveCurrentHunk() {
            if let header = currentHunkHeader {
                currentHunks.append(DiffHunk(
                    header: header,
                    oldStart: currentOldStart,
                    oldCount: currentOldCount,
                    newStart: currentNewStart,
                    newCount: currentNewCount,
                    lines: currentHunkLines
                ))
            }
            currentHunkLines = []
            currentHunkHeader = nil
        }
        
        func saveCurrentFile() {
            saveCurrentHunk()
            if let path = currentPath {
                diffs.append(FileDiff(
                    path: path,
                    oldPath: currentOldPath,
                    isBinary: isBinary,
                    hunks: currentHunks
                ))
            }
            currentPath = nil
            currentOldPath = nil
            currentHunks = []
            isBinary = false
        }
        
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("diff --git ") {
                saveCurrentFile()
                // Extract path from "diff --git a/path b/path"
                let parts = line.split(separator: " ")
                if parts.count >= 4 {
                    currentPath = String(parts[3]).replacingOccurrences(of: "b/", with: "", options: .anchored)
                }
            } else if line.hasPrefix("--- a/") {
                currentOldPath = String(line.dropFirst("--- a/".count))
            } else if line.hasPrefix("+++ b/") {
                currentPath = String(line.dropFirst("+++ b/".count))
            } else if line.hasPrefix("Binary files") {
                isBinary = true
            } else if line.hasPrefix("@@") {
                saveCurrentHunk()
                currentHunkHeader = line
                // Parse "@@ -oldStart,oldCount +newStart,newCount @@"
                if let range = parseHunkHeader(line) {
                    currentOldStart = range.oldStart
                    currentOldCount = range.oldCount
                    currentNewStart = range.newStart
                    currentNewCount = range.newCount
                    oldLineNum = range.oldStart
                    newLineNum = range.newStart
                }
                currentHunkLines.append(DiffLine(
                    kind: .hunkHeader,
                    content: line,
                    oldLineNumber: nil,
                    newLineNumber: nil
                ))
            } else if currentHunkHeader != nil {
                if line.hasPrefix("+") {
                    currentHunkLines.append(DiffLine(
                        kind: .addition,
                        content: String(line.dropFirst()),
                        oldLineNumber: nil,
                        newLineNumber: newLineNum
                    ))
                    newLineNum += 1
                } else if line.hasPrefix("-") {
                    currentHunkLines.append(DiffLine(
                        kind: .deletion,
                        content: String(line.dropFirst()),
                        oldLineNumber: oldLineNum,
                        newLineNumber: nil
                    ))
                    oldLineNum += 1
                } else if line.hasPrefix(" ") || line.isEmpty {
                    currentHunkLines.append(DiffLine(
                        kind: .context,
                        content: line.isEmpty ? "" : String(line.dropFirst()),
                        oldLineNumber: oldLineNum,
                        newLineNumber: newLineNum
                    ))
                    oldLineNum += 1
                    newLineNum += 1
                }
            }
        }
        
        saveCurrentFile()
        return diffs
    }
    
    private static func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)? {
        // Parse "@@ -10,5 +10,7 @@" or "@@ -10 +10 @@"
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        func extractInt(_ rangeIndex: Int) -> Int? {
            guard let range = Range(match.range(at: rangeIndex), in: line) else { return nil }
            return Int(line[range])
        }
        
        let oldStart = extractInt(1) ?? 0
        let oldCount = extractInt(2) ?? 1
        let newStart = extractInt(3) ?? 0
        let newCount = extractInt(4) ?? 1
        
        return (oldStart, oldCount, newStart, newCount)
    }
    
    // MARK: - Numstat Parsing
    
    static func parseNumstat(_ output: String) -> (insertions: Int, deletions: Int, files: Int) {
        var insertions = 0
        var deletions = 0
        var files = 0
        
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: "\t")
            if parts.count >= 2,
               let added = Int(parts[0]),
               let removed = Int(parts[1]) {
                insertions += added
                deletions += removed
                files += 1
            }
        }
        
        return (insertions, deletions, files)
    }
}
