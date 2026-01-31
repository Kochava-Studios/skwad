import Foundation

/// Unified async delay utilities to replace scattered timing mechanisms
@MainActor
struct AsyncDelay {
    /// Async-friendly delay using Task.sleep
    /// - Parameter duration: Time to wait in seconds
    static func wait(_ duration: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    /// Dispatch an action to main queue after a delay
    /// - Parameters:
    ///   - delay: Time to wait in seconds
    ///   - action: Closure to execute after delay
    static func dispatch(after delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated {
                action()
            }
        }
    }
}
