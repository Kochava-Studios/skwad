import Foundation
import AppKit
import SwiftTerm

/// How the terminal handles initial command execution
enum TerminalCommandMode {
    /// Command must be provided at terminal creation (Ghostty's initial_input)
    case atCreation
    /// Command should be sent after terminal is ready (SwiftTerm)
    case afterReady
}

/// Protocol for terminal adapters - abstracts Ghostty/SwiftTerm differences
///
/// Terminal views implement this protocol to provide a unified interface
/// for the TerminalSessionController. Views become dumb wrappers that only:
/// - Create the underlying terminal
/// - Forward events to controller via callbacks
/// - Execute text injection when told
@MainActor
protocol TerminalAdapter: AnyObject {
    /// How this terminal handles initial command execution
    var commandMode: TerminalCommandMode { get }

    /// Send text to the terminal (no return key)
    func sendText(_ text: String)

    /// Send return key to the terminal
    func sendReturn()

    /// Focus the terminal
    func focus()
    
    /// Notify terminal to resize/relayout
    func notifyResize()

    /// Activate the adapter - wires terminal callbacks to adapter properties
    /// Called by controller after all callbacks are set
    func activate()

    /// Clean up adapter resources on termination
    /// Note: Actual process termination happens when surfaces are freed
    func terminate()

    // Events emitted to controller
    var onActivity: (() -> Void)? { get set }
    var onReady: (() -> Void)? { get set }
    var onProcessExit: ((Int32?) -> Void)? { get set }
    var onTitleChange: ((String) -> Void)? { get set }
}

// MARK: - Protocol Extension

extension TerminalAdapter {
    /// Default activate implementation - subclasses can override to wire additional callbacks
    /// Tracks callback wiring state via callbacksWired property
    func activateCallbacks<T: AnyObject>(
        terminal: T?,
        callbacksWired: inout Bool,
        wireCallbacks: (T) -> Void
    ) {
        guard let terminal = terminal, !callbacksWired else { return }
        callbacksWired = true
        wireCallbacks(terminal)
    }
}

// MARK: - Ghostty Adapter

/// Adapter wrapping GhosttyTerminalView
@MainActor
class GhosttyTerminalAdapter: TerminalAdapter {
    private weak var terminal: GhosttyTerminalView?
    private var callbacksWired = false

    let commandMode: TerminalCommandMode = .atCreation

    var onActivity: (() -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?

    init(terminal: GhosttyTerminalView) {
        self.terminal = terminal
        // Don't wire callbacks here - wait until activate() is called
    }

    /// Wire terminal callbacks to adapter properties
    /// Called by controller after all callbacks are set
    func activate() {
        activateCallbacks(terminal: terminal, callbacksWired: &callbacksWired) { [weak self] terminal in
            terminal.onActivity = { [weak self] in
                self?.onActivity?()
            }
            terminal.onReady = { [weak self] in
                self?.onReady?()
            }
            terminal.onProcessExit = { [weak self] in
                self?.onProcessExit?(nil)
            }
            terminal.onTitleChange = { [weak self] title in
                self?.onTitleChange?(title)
            }

            // If terminal already signaled ready before we wired, fire now
            if terminal.didSignalReady {
                self?.onReady?()
            }
        }
    }

    func sendText(_ text: String) {
        terminal?.surface?.sendText(text)
    }

    func sendReturn() {
        guard let surface = terminal?.surface else { return }
        let event = Ghostty.Input.KeyEvent(key: .enter, action: .press, text: "\r")
        surface.sendKeyEvent(event)
    }

    func focus() {
        guard let terminal = terminal else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    func terminate() {
        // Ghostty: Release reference to terminal
        // The underlying process will be terminated when the surface is freed
        // We can't reliably send commands since TUI apps intercept them
        terminal = nil
    }
    
    func notifyResize() {
        guard let terminal = terminal else { return }
        // Trigger a layout update which will call ghostty_surface_set_size
        terminal.needsLayout = true
        terminal.layoutSubtreeIfNeeded()
    }
}

// MARK: - SwiftTerm Adapter

/// Adapter wrapping ActivityDetectingTerminalView (SwiftTerm)
@MainActor
class SwiftTermAdapter: TerminalAdapter {
    private weak var terminal: ActivityDetectingTerminalView?
    private var callbacksWired = false

    let commandMode: TerminalCommandMode = .afterReady

    var onActivity: (() -> Void)?
    var onReady: (() -> Void)?
    var onProcessExit: ((Int32?) -> Void)?
    var onTitleChange: ((String) -> Void)?  // SwiftTerm ignores this

    init(terminal: ActivityDetectingTerminalView) {
        self.terminal = terminal
        // Don't wire callbacks here - wait until activate() is called
    }

    /// Wire terminal callbacks to adapter properties
    /// Called by controller after all callbacks are set
    func activate() {
        activateCallbacks(terminal: terminal, callbacksWired: &callbacksWired) { [weak self] terminal in
            terminal.onActivity = { [weak self] in
                self?.onActivity?()
            }
            // Note: SwiftTerm doesn't have onReady/onProcessExit callbacks on the view
            // These are handled via LocalProcessTerminalViewDelegate and notifyReady/notifyProcessExit
        }
    }

    func sendText(_ text: String) {
        terminal?.send(txt: text)
    }

    func sendReturn() {
        // SwiftTerm just needs the carriage return character
        terminal?.send(txt: "\r")
    }

    func focus() {
        guard let terminal = terminal else { return }
        terminal.window?.makeFirstResponder(terminal)
    }

    /// Called by coordinator when process terminates
    func notifyProcessExit(exitCode: Int32?) {
        onProcessExit?(exitCode)
    }

    /// Called by coordinator when terminal is ready
    func notifyReady() {
        onReady?()
    }

    func terminate() {
        // SwiftTerm: Release reference to terminal
        // The underlying process will be terminated when the view is deallocated
        // We can't reliably send commands since TUI apps intercept them
        terminal = nil
    }
    
    func notifyResize() {
        guard let terminal = terminal else { return }
        // Trigger a layout update which will resize the terminal grid
        terminal.needsLayout = true
        terminal.layoutSubtreeIfNeeded()
    }
}
