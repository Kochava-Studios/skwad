//
//  GhosttyHostView.swift
//  Skwad
//
//  Alternative terminal view using libghostty instead of SwiftTerm
//

import SwiftUI
import AppKit

/// SwiftUI wrapper for GhosttyTerminalView
struct GhosttyHostView: NSViewRepresentable {
    let controller: TerminalSessionController
    let size: CGSize
    let isActive: Bool
    let suppressFocus: Bool
    let onTerminalCreated: (GhosttyTerminalView) -> Void
    let onPaneTap: (() -> Void)?

    func makeNSView(context: Context) -> TerminalScrollView {
        // Initialize Ghostty if not already done
        if !GhosttyAppManager.shared.isReady {
            GhosttyAppManager.shared.initialize()
        }

        guard let ghosttyApp = GhosttyAppManager.shared.app else {
            fatalError("Ghostty initialization failed")
        }

        // Build command - Ghostty needs it at creation time
        let command = controller.buildInitializationCommand()

        // Create the Ghostty terminal view with command
        let terminal = GhosttyTerminalView(
            frame: NSRect(x: 0, y: 0, width: max(1, size.width), height: max(1, size.height)),
            worktreePath: controller.folder,
            ghosttyApp: ghosttyApp,
            appWrapper: GhosttyAppManager.shared.appWrapper,
            paneId: controller.agentId.uuidString,
            command: command
        )

        // Create adapter and attach to controller
        let adapter = GhosttyTerminalAdapter(terminal: terminal)
        controller.attach(to: adapter)

        // Store terminal reference in context for focus management
        context.coordinator.terminal = terminal

        terminal.onMouseDown = onPaneTap

        // Notify parent that terminal is created
        DispatchQueue.main.async {
            self.onTerminalCreated(terminal)
        }

        // Wrap terminal in scroll view for better size synchronization
        let scrollView = TerminalScrollView(contentSize: size, surfaceView: terminal)
        return scrollView
    }

    func updateNSView(_ nsView: TerminalScrollView, context: Context) {
        // Ensure view matches the allocated size to trigger layout updates
        if nsView.frame.size != size || nsView.frame.origin != .zero {
            nsView.frame = CGRect(origin: .zero, size: size)
            nsView.needsLayout = true
            nsView.layoutSubtreeIfNeeded()
        }

        // Focus terminal when active
        if isActive && !suppressFocus {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView.surfaceView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Minimal coordinator - just holds terminal reference for focus
    @MainActor
    class Coordinator: NSObject {
        weak var terminal: GhosttyTerminalView?
    }
}

// MARK: - Ghostty App Manager

/// Singleton manager for the Ghostty app instance
@MainActor
class GhosttyAppManager {
    static let shared = GhosttyAppManager()

    private(set) var appWrapper: Ghostty.App?

    var app: ghostty_app_t? {
        appWrapper?.app
    }

    var isReady: Bool {
        appWrapper?.readiness == .ready
    }

    private init() {}

    /// Initialize the Ghostty app - call this at app startup
    func initialize() {
        guard appWrapper == nil else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil else { return }
        appWrapper = Ghostty.App()

        if appWrapper?.readiness == .ready {
            print("[skwad] Ghostty initialized successfully")
        } else {
            print("[skwad] Ghostty initialization failed")
        }
    }

    /// Clean up Ghostty resources - call at app termination
    func cleanup() {
        appWrapper?.cleanup()
        appWrapper = nil
    }
}
