import Foundation
import Observation

/// Background service that discovers repositories in the source base folder
/// and keeps the list updated with a shallow (depth=1) file system monitor.
@Observable
@MainActor
final class RepoDiscoveryService {
    static let shared = RepoDiscoveryService()

    private(set) var repos: [RepoInfo] = []
    private(set) var isLoading: Bool = false

    private let queue = DispatchQueue(label: "RepoDiscoveryService", qos: .utility)
    private var stream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?

    private var baseFolderRaw: String = ""
    private var baseFolderExpanded: String = ""

    /// Strong reference holder for FSEvents callback - prevents use-after-free
    private var callbackContext: Unmanaged<RepoDiscoveryService>?

    private init() {
    }

    func start() {

        // Skip initialization in Xcode Previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }

        updateBaseFolder(AppSettings.shared.sourceBaseFolder)
    }

    func updateBaseFolder(_ baseFolder: String) {
        let trimmed = baseFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = PathUtils.expanded(trimmed)

        guard expanded != baseFolderExpanded else { return }

        baseFolderRaw = trimmed
        baseFolderExpanded = expanded

        stopWatcher()
        debounceTask?.cancel()
        debounceTask = nil

        repos = []
        isLoading = false

        guard !trimmed.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        refreshRepos(thenWatch: expanded)
    }

    private func refreshRepos(thenWatch watchPath: String? = nil) {
        let baseFolder = baseFolderRaw
        guard !baseFolder.isEmpty else { return }

        isLoading = true

        Task.detached(priority: .userInitiated) {
            let repos = Self.scanRepos(in: baseFolder)

            await MainActor.run { [weak self] in
                guard let self, baseFolder == self.baseFolderRaw else { return }
                self.repos = repos
                self.isLoading = false

                if let watchPath {
                    self.startWatcher(path: watchPath)
                }
            }
        }
    }

    private func startWatcher(path: String) {
        guard stream == nil else { return }

        let pathsToWatch = [path] as CFArray

        // Use passRetained to ensure the service stays alive during callbacks
        callbackContext = Unmanaged.passRetained(self)

        var context = FSEventStreamContext(
            version: 0,
            info: callbackContext?.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes)

        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<RepoDiscoveryService>.fromOpaque(info).takeUnretainedValue()
                watcher.handleEventsFromCallback(numEvents: numEvents, paths: eventPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        )

        guard let stream = stream else {
            callbackContext?.release()
            callbackContext = nil
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func stopWatcher() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil

        // Release the retained reference
        callbackContext?.release()
        callbackContext = nil
    }

    /// Called from FSEvents callback (off main actor)
    private nonisolated func handleEventsFromCallback(numEvents: Int, paths: UnsafeMutableRawPointer) {
        // Safely extract paths from CF types
        let cfArray = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue()
        guard let pathArray = cfArray as? [String] else { return }

        Task { @MainActor [weak self] in
            self?.handleEvents(paths: pathArray)
        }
    }

    private func handleEvents(paths: [String]) {
        guard shouldRefresh(for: paths) else { return }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(TimingConstants.repoDiscoveryDebounce))
            guard !Task.isCancelled else { return }
            self?.refreshRepos()
        }
    }

    // MARK: - Filesystem Scanning

    /// Pure filesystem scan — no git commands.
    nonisolated static func scanRepos(in baseFolder: String) -> [RepoInfo] {
        let expandedPath = NSString(string: baseFolder).expandingTildeInPath
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: expandedPath) else {
            return []
        }

        var repoNames: [String: String] = [:]
        var worktreesByRepoPath: [String: [WorktreeInfo]] = [:]

        for item in contents {
            let itemPath = (expandedPath as NSString).appendingPathComponent(item)
            let gitPath = (itemPath as NSString).appendingPathComponent(".git")

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: gitPath, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                repoNames[itemPath] = item
                let branchName = parseBranchFromHead(gitPath) ?? item
                worktreesByRepoPath[itemPath, default: []].insert(
                    WorktreeInfo(name: branchName, path: itemPath), at: 0
                )
            } else {
                if let repoPath = parseWorktreeGitFile(gitPath) {
                    let repoName = (repoPath as NSString).lastPathComponent
                    let wtName = item.hasPrefix("\(repoName)-") ? String(item.dropFirst(repoName.count + 1)) : item
                    worktreesByRepoPath[repoPath, default: []].append(
                        WorktreeInfo(name: wtName, path: itemPath)
                    )
                }
            }
        }

        var result: [RepoInfo] = []
        for (repoPath, name) in repoNames {
            let worktrees = worktreesByRepoPath[repoPath] ?? []
            result.append(RepoInfo(name: name, worktrees: worktrees))
        }

        return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private nonisolated static func parseBranchFromHead(_ gitDirPath: String) -> String? {
        let headPath = (gitDirPath as NSString).appendingPathComponent("HEAD")
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("ref: refs/heads/") else { return nil }
        return String(trimmed.dropFirst("ref: refs/heads/".count))
    }

    private nonisolated static func parseWorktreeGitFile(_ path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("gitdir: ") else { return nil }
        let gitdir = String(trimmed.dropFirst("gitdir: ".count))
        guard let range = gitdir.range(of: "/.git/worktrees/") else { return nil }
        return String(gitdir[gitdir.startIndex..<range.lowerBound])
    }

    // MARK: - FSEvents Filtering

    private func shouldRefresh(for paths: [String]) -> Bool {
        let basePath = baseFolderExpanded
        guard !basePath.isEmpty else { return false }

        for path in paths {
            guard path.hasPrefix(basePath) else { continue }

            var relative = String(path.dropFirst(basePath.count))
            if relative.hasPrefix("/") { relative.removeFirst() }
            if relative.isEmpty { return true }

            let components = relative.split(separator: "/", omittingEmptySubsequences: true)

            if components.count == 1 {
                return true // direct child added/removed
            }

            // .git event: only care if this is a new repo we don't know about yet
            // (FSEvents reports .git/ for any activity inside it, not just creation)
            if components.count == 2, components[1] == ".git" {
                let folderName = String(components[0])
                if !repos.contains(where: { $0.name == folderName }) {
                    return true 
                }
            }
        }

        return false
    }
}
