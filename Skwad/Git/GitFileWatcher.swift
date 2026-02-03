import Foundation

/// Watches a directory for file system changes using FSEvents
final class GitFileWatcher {
    private var stream: FSEventStreamRef?
    private let path: String
    private let callback: () -> Void

    private var debounceTask: Task<Void, Never>?
    private var isPaused = false
    private let queue = DispatchQueue(label: "GitFileWatcher", qos: .utility)

    /// Strong reference holder for FSEvents callback - prevents use-after-free
    private var callbackContext: Unmanaged<GitFileWatcher>?

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

        // Use passRetained to ensure the watcher stays alive during callbacks
        callbackContext = Unmanaged.passRetained(self)

        var context = FSEventStreamContext(
            version: 0,
            info: callbackContext?.toOpaque(),
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
                watcher.handleEventsFromCallback(numEvents: numEvents, paths: eventPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // Latency - coalesce events over 1 second
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

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        guard let stream = stream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil

        // Release the retained reference
        callbackContext?.release()
        callbackContext = nil
    }

    /// Temporarily pause watching (e.g., during refresh)
    func pause() {
        isPaused = true
    }

    /// Resume watching
    func resume() {
        isPaused = false
    }

    /// Called from FSEvents callback (off main thread)
    private func handleEventsFromCallback(numEvents: Int, paths: UnsafeMutableRawPointer) {
        guard !isPaused else { return }

        // Safely extract paths from CF types
        let cfArray = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue()
        guard let pathArray = cfArray as? [String] else { return }

        // Filter out .git internal changes that don't affect status
        let relevantChange = pathArray.contains { path in
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

        // Cancel any pending work and schedule new callback with debounce
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(TimingConstants.gitFileWatcherDebounce))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.callback()
            }
        }
    }
}
