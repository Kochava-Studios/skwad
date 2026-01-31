import SwiftUI
import SwiftTerm
import Carbon.HIToolbox

// Custom terminal view that detects activity via dataReceived
class ActivityDetectingTerminalView: LocalProcessTerminalView {
    var onActivity: (() -> Void)?

    // Called when data is received from the process (output)
    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onActivity?()
    }
}

struct TerminalHostView: NSViewRepresentable {
    let controller: TerminalSessionController
    let isActive: Bool

    @ObservedObject private var settings = AppSettings.shared

    func makeNSView(context: Context) -> ActivityDetectingTerminalView {
        let terminal = ActivityDetectingTerminalView(frame: .zero)

        // Prepare (writes MCP config)
        controller.prepare()

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

        return terminal
    }

    func updateNSView(_ nsView: ActivityDetectingTerminalView, context: Context) {
        // Apply settings (in case they changed)
        applySettings(to: nsView)

        // Focus terminal when active
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
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

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            adapter?.notifyProcessExit(exitCode: exitCode)
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
