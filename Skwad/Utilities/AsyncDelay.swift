import Foundation

/// Unified async delay utilities using modern Swift concurrency
@MainActor
enum AsyncDelay {
    /// Async-friendly delay using Task.sleep
    /// - Parameter duration: Time to wait in seconds
    static func wait(_ duration: TimeInterval) async {
        try? await Task.sleep(for: .seconds(duration))
    }

    /// Dispatch an action to main actor after a delay using Task
    /// - Parameters:
    ///   - delay: Time to wait in seconds
    ///   - action: Closure to execute after delay
    @discardableResult
    static func dispatch(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
