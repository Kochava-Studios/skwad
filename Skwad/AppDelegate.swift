//
//  AppDelegate.swift
//  Skwad
//
//  Application delegate for handling app lifecycle events
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var agentManager: AgentManager?
    var mcpServer: MCPServer?
    var menuBarManager: MenuBarManager?

    /// Reference to main window (kept to restore after hiding)
    private var mainWindow: NSWindow?

    /// Flag to distinguish real quit from hide-to-menu-bar
    private var isQuittingForReal = false

    /// Observer for settings changes
    private var settingsObserver: NSObjectProtocol?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // When keep in menu bar is enabled, don't quit when window closes
        return !AppSettings.shared.keepInMenuBar
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If quitting for real (from menu bar), allow it
        if isQuittingForReal {
            return .terminateNow
        }

        // If keep in menu bar is enabled, hide instead of quit
        if AppSettings.shared.keepInMenuBar {
            hideMainWindow()
            return .terminateCancel
        }

        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[skwad] Application terminating - cleaning up resources")

        // Terminate all agent processes first
        agentManager?.terminateAll()

        // Clean up Ghostty resources
        GhosttyAppManager.shared.cleanup()

        // Clean up menu bar
        menuBarManager?.teardown()

        // Stop MCP server (fire and forget - system will kill process anyway)
        if let server = mcpServer {
            Task {
                await server.stop()
            }
            mcpServer = nil
        }

        print("[skwad] Cleanup complete")
    }

    // MARK: - Menu Bar Support

    func setupMenuBarIfNeeded() {
        // Setup observer for setting changes (only once)
        if settingsObserver == nil {
            settingsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateMenuBarState()
            }
        }

        updateMenuBarState()
    }

    private func updateMenuBarState() {
        if AppSettings.shared.keepInMenuBar {
            if menuBarManager == nil {
                menuBarManager = MenuBarManager(appDelegate: self)
            }
            menuBarManager?.setup()
        } else {
            menuBarManager?.teardown()
        }
    }

    func showMainWindow() {
        guard let window = mainWindow else {
            print("[skwad] No main window reference!")
            return
        }

        // First unhide the app (critical for accessory -> regular transition)
        NSApp.unhide(nil)

        // Make window visible and bring to front
        window.setIsVisible(true)
        window.makeKeyAndOrderFront(nil)

        // Now switch to regular activation policy (shows dock icon)
        NSApp.setActivationPolicy(.regular)

        // Finally activate the app to ensure focus
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideMainWindow() {
        // Save reference to main window before hiding
        if mainWindow == nil {
            mainWindow = NSApp.windows.first(where: { $0.canBecomeMain })
        }

        // Hide window first
        mainWindow?.orderOut(nil)

        // Then hide from dock
        NSApp.setActivationPolicy(.accessory)
    }

    func quitForReal() {
        isQuittingForReal = true
        NSApp.terminate(nil)
    }
}
