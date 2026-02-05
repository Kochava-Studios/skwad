import Foundation

/// Centralized timing constants used throughout the app
/// All values in seconds (TimeInterval)
enum TimingConstants {
    // MARK: - Terminal Operations

    /// Delay between sending text and pressing return key
    /// Used to ensure text is fully written before return
    static let returnKeyDelay: TimeInterval = 0.1

    /// Delay for SwiftTerm to initialize shell before marking ready
    static let terminalReadyDelay: TimeInterval = 0.5

    /// Timeout for marking terminal as idle after last terminal output
    static let idleTimeout: TimeInterval = 2.0

    /// Timeout for marking terminal as idle after last user input (keypress)
    static let userInputIdleTimeout: TimeInterval = 10.0

    /// First idle delay for fast-starting agents  
    static let registrationFirstIdleDelayShort: TimeInterval = 1.5
    
    /// First idle delay for slow-starting agents (e.g. Gemini)
    static let registrationFirstIdleDelayLong: TimeInterval = 5.0
    
    /// Subsequent idle delay before injecting MCP registration prompt
    static let registrationSubsequentIdleDelay: TimeInterval = 1.5

    // MARK: - Git Operations

    /// Debounce delay for file system change notifications
    static let gitFileWatcherDebounce: TimeInterval = 1.0

    /// Delay before resuming file watcher after git operations
    static let gitFileWatcherResume: TimeInterval = 0.5

    /// Debounce delay for repository discovery refresh
    static let repoDiscoveryDebounce: TimeInterval = 1.0

    /// Polling interval for git process timeout check
    static let gitProcessPollInterval: TimeInterval = 0.1

    // MARK: - UI Feedback

    /// Duration to show "copied" checkmark before resetting
    static let copiedIndicatorDuration: TimeInterval = 2.0

    // MARK: - File Watching

    /// Debounce delay for file watcher notifications
    static let fileWatcherDebounce: TimeInterval = 0.3
}
