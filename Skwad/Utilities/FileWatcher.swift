import Foundation

/// Watches a single file for changes using FSEvents
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let filePath: String
    private let callback: () -> Void

    private var debounceTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "FileWatcher", qos: .utility)

    /// Strong reference holder for FSEvents callback - prevents use-after-free
    private var callbackContext: Unmanaged<FileWatcher>?

    /// Track file modification time to detect actual changes
    private var lastModificationDate: Date?

    init(filePath: String, onChange: @escaping () -> Void) {
        self.filePath = filePath
        self.callback = onChange
        self.lastModificationDate = getModificationDate()
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }

        // Watch the parent directory since FSEvents doesn't watch individual files well
        let directory = (filePath as NSString).deletingLastPathComponent
        let pathsToWatch = [directory] as CFArray

        // Use passRetained to ensure the watcher stays alive during callbacks
        callbackContext = Unmanaged.passRetained(self)

        var context = FSEventStreamContext(
            version: 0,
            info: callbackContext?.toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)

        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, _, _ in
                guard let info = info else { return }
                let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.handleEventsFromCallback(numEvents: numEvents, paths: eventPaths)
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // Latency - coalesce events over 0.5 second
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

    /// Get the modification date of the watched file
    private func getModificationDate() -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        return attrs?[.modificationDate] as? Date
    }

    /// Called from FSEvents callback (off main thread)
    private func handleEventsFromCallback(numEvents: Int, paths: UnsafeMutableRawPointer) {
        // Safely extract paths from CF types
        let cfArray = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue()
        guard let pathArray = cfArray as? [String] else { return }

        // Check if our specific file was modified
        let fileName = (filePath as NSString).lastPathComponent
        let fileChanged = pathArray.contains { path in
            (path as NSString).lastPathComponent == fileName
        }

        guard fileChanged else { return }

        // Verify the file was actually modified by checking modification date
        let currentModDate = getModificationDate()
        guard currentModDate != lastModificationDate else { return }
        lastModificationDate = currentModDate

        // Cancel any pending work and schedule new callback with debounce
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(TimingConstants.fileWatcherDebounce))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.callback()
            }
        }
    }
}
