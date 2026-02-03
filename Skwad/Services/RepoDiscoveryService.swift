import Foundation
import Observation

/// Background service that discovers repositories in the source base folder
/// and keeps the list updated with a shallow (depth=1) file system monitor.
@Observable
@MainActor
final class RepoDiscoveryService {
    static let shared = RepoDiscoveryService()

    private(set) var repos: [RepoInfo] = []
    private(set) var worktreesByRepoPath: [String: [WorktreeInfo]] = [:]
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
        worktreesByRepoPath = [:]
        isLoading = false

        guard !trimmed.isEmpty else { return }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        refreshRepos()
        startWatcher(path: expanded)
    }

    private func refreshRepos() {
        let baseFolder = baseFolderRaw
        guard !baseFolder.isEmpty else { return }

        isLoading = true

        Task.detached(priority: .userInitiated) {
            let discovered = GitWorktreeManager.shared.discoverReposWithWorktrees(in: baseFolder)
            let repos = discovered.map { $0.repo }
            let worktreesMap = Dictionary(uniqueKeysWithValues: discovered.map { ($0.repo.path, $0.worktrees) })

            await MainActor.run { [weak self] in
                guard let self, baseFolder == self.baseFolderRaw else { return }
                self.repos = repos
                self.worktreesByRepoPath = worktreesMap
                self.isLoading = false
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

            if components.count == 2, components[1] == ".git" {
                return true // git init (repo created)
            }

            if components.count == 3, components[1] == ".git" {
                let tail = components[2]
                if tail == "HEAD" || tail == "index" {
                    return true
                }
            }
        }

        return false
    }
}
