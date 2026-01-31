import Foundation

/// Background service that discovers repositories in the source base folder
/// and keeps the list updated with a shallow (depth=1) file system monitor.
final class RepoDiscoveryService: ObservableObject {
    static let shared = RepoDiscoveryService()

    @Published private(set) var repos: [RepoInfo] = []
    @Published private(set) var worktreesByRepoPath: [String: [WorktreeInfo]] = [:]
    @Published private(set) var isLoading: Bool = false

    private let queue = DispatchQueue(label: "RepoDiscoveryService", qos: .utility)
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?

    private var baseFolderRaw: String = ""
    private var baseFolderExpanded: String = ""

    private init() {}

    func start() {
        updateBaseFolder(AppSettings.shared.sourceBaseFolder)
    }

    func updateBaseFolder(_ baseFolder: String) {
        let trimmed = baseFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = NSString(string: trimmed).expandingTildeInPath

        guard expanded != baseFolderExpanded else { return }

        baseFolderRaw = trimmed
        baseFolderExpanded = expanded

        stopWatcher()
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        DispatchQueue.main.async {
            self.repos = []
            self.worktreesByRepoPath = [:]
            self.isLoading = false
        }

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

        DispatchQueue.main.async {
            self.isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = GitWorktreeManager.shared.discoverReposWithWorktrees(in: baseFolder)
            let repos = discovered.map { $0.repo }
            let worktreesMap = Dictionary(uniqueKeysWithValues: discovered.map { ($0.repo.path, $0.worktrees) })
            DispatchQueue.main.async {
                guard baseFolder == self.baseFolderRaw else { return }
                self.repos = repos
                self.worktreesByRepoPath = worktreesMap
                self.isLoading = false
            }
        }
    }

    private func startWatcher(path: String) {
        guard stream == nil else { return }

        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
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
                watcher.handleEvents(numEvents: numEvents, paths: eventPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        )

        guard let stream = stream else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func stopWatcher() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handleEvents(numEvents: Int, paths: UnsafeMutableRawPointer) {
        guard let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
        guard shouldRefresh(for: paths) else { return }

        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshRepos()
        }
        debounceWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + TimingConstants.repoDiscoveryDebounce, execute: workItem)
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
