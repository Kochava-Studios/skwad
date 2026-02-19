import SwiftUI
import SwiftTerm
import Carbon.HIToolbox

// Custom terminal view that detects activity via dataReceived and user input
class ActivityDetectingTerminalView: LocalProcessTerminalView {
    var onActivity: (() -> Void)?
    var onUserInput: ((UInt16) -> Void)?

    // Called when data is received from the process (output)
    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onActivity?()
    }

    // SwiftTerm's keyDown is not open for override, so we use a local event monitor
    // to capture keyCodes for input state handling (Return/Escape detection)
    private var keyMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if let self = self, event.window === self.window, self.window?.firstResponder === self {
                    self.onUserInput?(event.keyCode)
                }
                return event
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil, let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

/// Transparent wrapper that intercepts mouseDown to notify the pane, then forwards to the terminal
class TerminalContainerView: NSView {
    var onMouseDown: (() -> Void)?
    weak var terminal: ActivityDetectingTerminalView?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        terminal?.mouseDown(with: event)
    }

    override var acceptsFirstResponder: Bool { false }
}

struct TerminalHostView: NSViewRepresentable {
    let controller: TerminalSessionController
    let isActive: Bool
    let onPaneTap: (() -> Void)?

    @ObservedObject private var settings = AppSettings.shared

    func makeNSView(context: Context) -> TerminalContainerView {
        let terminal = ActivityDetectingTerminalView(frame: .zero)

        // Configure terminal appearance from settings
        applySettings(to: terminal)

        // Get user's default shell
        let shell = TerminalCommandBuilder.getDefaultShell()

        // Start an interactive login shell
        // Using -i -l ensures full environment is loaded (.zshrc, .zprofile, etc.)
        terminal.startProcess(
            executable: shell,
            args: ["-i", "-l"],
            environment: nil,
            execName: nil
        )

        // Set up delegate for process exit
        terminal.processDelegate = context.coordinator

        // Create adapter and attach to controller
        let adapter = SwiftTermAdapter(terminal: terminal)
        context.coordinator.adapter = adapter
        controller.attach(to: adapter)

        // SwiftTerm is ready immediately after process starts
        // Signal ready after a brief delay for shell initialization
        AsyncDelay.dispatch(after: TimingConstants.terminalReadyDelay) {
            adapter.notifyReady()
        }

        // Wrap terminal in container that intercepts mouseDown for pane focus
        let container = TerminalContainerView(frame: .zero)
        container.onMouseDown = onPaneTap
        container.terminal = terminal
        container.addSubview(terminal)
        context.coordinator.container = container

        return container
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        guard let terminal = nsView.terminal else { return }

        // Keep terminal filling the container
        terminal.frame = nsView.bounds

        // Apply settings (in case they changed)
        applySettings(to: terminal)

        // Focus terminal when active
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(terminal)
            }
        }
    }

    private func applySettings(to terminal: ActivityDetectingTerminalView) {
        terminal.font = settings.terminalFont
        terminal.nativeBackgroundColor = settings.terminalNSBackgroundColor
        terminal.nativeForegroundColor = settings.terminalNSForegroundColor
        terminal.caretColor = settings.terminalNSBackgroundColor  // Hide cursor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Minimal coordinator - handles delegate callbacks
    @MainActor
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var adapter: SwiftTermAdapter?
        var container: TerminalContainerView?

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            adapter?.notifyProcessExit(exitCode: exitCode)
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
