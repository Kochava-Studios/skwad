import Foundation
@testable import Skwad

/// Mock implementation of TerminalAdapter for testing TerminalSessionController
@MainActor
class MockTerminalAdapter: TerminalAdapter {
    let commandMode: TerminalCommandMode = .afterReady

    var onActivity: (() -> Void)?
    var onUserInput: ((UInt16) -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?

    // Recorded calls for assertions
    private(set) var sentTexts: [String] = []
    private(set) var sentReturns = 0
    private(set) var focusCalls = 0
    private(set) var terminateCalls = 0
    private(set) var resizeCalls = 0
    private(set) var activateCalls = 0

    func sendText(_ text: String) {
        sentTexts.append(text)
    }

    func sendReturn() {
        sentReturns += 1
    }

    func focus() {
        focusCalls += 1
    }

    func notifyResize() {
        resizeCalls += 1
    }

    func activate() {
        activateCalls += 1
    }

    func terminate() {
        terminateCalls += 1
    }

    // MARK: - Test Helpers

    /// Simulate terminal output activity
    func simulateActivity() {
        onActivity?()
    }

    /// Simulate user keypress with keyCode
    func simulateUserInput(keyCode: UInt16 = 0) {
        onUserInput?(keyCode)
    }

    /// Simulate terminal ready
    func simulateReady() {
        onReady?()
    }

    /// Simulate process exit
    func simulateProcessExit(code: Int32? = nil) {
        onProcessExit?(code)
    }

    /// Reset all recorded calls
    func reset() {
        sentTexts.removeAll()
        sentReturns = 0
        focusCalls = 0
        terminateCalls = 0
        resizeCalls = 0
    }
}
