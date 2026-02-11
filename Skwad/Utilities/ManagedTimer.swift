import Foundation

/// A helper class that manages a single Timer lifecycle with automatic cleanup.
///
/// ManagedTimer eliminates boilerplate timer management by:
/// - Automatically invalidating existing timers when scheduling new ones
/// - Providing automatic cleanup in deinit
/// - Simplifying the schedule/invalidate pattern
///
/// Usage:
/// ```swift
/// private let idleTimer = ManagedTimer()
///
/// // Schedule a timer
/// idleTimer.schedule(after: 2.0) { [weak self] in
///     self?.markIdle()
/// }
///
/// // Reschedule (automatically invalidates previous)
/// idleTimer.schedule(after: 2.0) { [weak self] in
///     self?.markIdle()
/// }
///
/// // Manual invalidation (optional - deinit handles this)
/// idleTimer.invalidate()
/// ```
@MainActor
class ManagedTimer {
    private var timer: Timer?

    /// Whether a timer is currently scheduled and hasn't fired yet
    var isActive: Bool { timer != nil }

    /// Schedule a new timer, invalidating any existing timer
    /// - Parameters:
    ///   - delay: Time interval in seconds before the timer fires
    ///   - action: Closure to execute when the timer fires
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) {
        invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.timer = nil
            action()
        }
    }

    /// Invalidate the current timer if one exists
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
}
