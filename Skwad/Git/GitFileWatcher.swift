import Foundation

/// Watches a directory for file system changes using FSEvents
class GitFileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let callback: () -> Void

    private var debounceWorkItem: DispatchWorkItem?
    private var isPaused = false
    private let queue = DispatchQueue(label: "GitFileWatcher", qos: .utility)

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.callback = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Remove kFSEventStreamCreateFlagFileEvents for less granular (and less noisy) updates
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes)

        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<GitFileWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.handleEvents(numEvents: numEvents, paths: eventPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // Latency - coalesce events over 1 second
            flags
        )

        guard let stream = stream else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        guard let stream = stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Temporarily pause watching (e.g., during refresh)
    func pause() {
        isPaused = true
    }

    /// Resume watching
    func resume() {
        isPaused = false
    }

    private func handleEvents(numEvents: Int, paths: UnsafeMutableRawPointer) {
        guard !isPaused else { return }
        guard let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }

        // Filter out .git internal changes that don't affect status
        let relevantChange = paths.contains { path in
            // Ignore most .git internals
            if path.contains("/.git/") {
                // Only care about index changes (staging) and HEAD changes (commits/checkouts)
                return path.hasSuffix("/.git/index") ||
                       path.hasSuffix("/.git/HEAD") ||
                       path.contains("/.git/refs/")
            }
            // Ignore hidden files and common noise
            let filename = (path as NSString).lastPathComponent
            if filename.hasPrefix(".") && filename != ".gitignore" {
                return false
            }
            return true
        }

        guard relevantChange else { return }

        // Cancel any pending work
        debounceWorkItem?.cancel()

        // Schedule new callback with longer debounce
        let workItem = DispatchWorkItem { [weak self] in
            self?.callback()
        }
        debounceWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + TimingConstants.gitFileWatcherDebounce, execute: workItem)
    }
}
