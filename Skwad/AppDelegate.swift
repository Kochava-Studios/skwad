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

    /// Monitor for keyboard events (Cmd+W interception)
    private var keyEventMonitor: Any?

    /// Observer for window close button interception
    private var windowCloseObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance: if another Skwad is already running, activate it and quit
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
        if let existing = runningInstances.first(where: { $0 != NSRunningApplication.current }) {
            existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }

        setupKeyEventMonitor()
        setupWindowCloseObserver()
        removeDefaultCloseMenuItem()
    }

    /// Intercept Cmd+W to close the focused agent instead of the window
    private func setupKeyEventMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd+W (keyCode 13 is 'W')
            if event.modifierFlags.contains(.command) && event.keyCode == 13 {
                // Only intercept plain Cmd+W, not Cmd+Shift+W
                if !event.modifierFlags.contains(.shift) {
                    self?.closeCurrentAgent()
                    return nil  // Consume the event
                }
            }
            return event  // Pass through other events
        }
    }

    /// Hijack the close button on the main window to hide instead of close
    private func setupWindowCloseObserver() {
        // Wait for the window to appear, then replace the close button's action
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let window = notification.object as? NSWindow,
                  window.canBecomeMain else { return }

            self.mainWindow = window

            // Replace the close button's target/action so it hides instead of closes
            if let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.target = self
                closeButton.action = #selector(self.closeButtonClicked)
            }
        }
    }

    @objc private func closeButtonClicked() {
        if AppSettings.shared.keepInMenuBar {
            hideMainWindow()
        } else {
            mainWindow?.close()
        }
    }

    /// Hide the default "Close" and "Close All" menu items from the File menu
    /// Cmd+W is handled by the key event monitor to close agents instead
    private func removeDefaultCloseMenuItem() {
        // SwiftUI keeps re-adding Close items, so we poll and neuter them
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu else { return }
            for item in fileMenu.items where item.keyEquivalent == "w" {
                // Replace with zero-size view — SwiftUI can't reset this like it resets isHidden
                item.view = NSView(frame: .zero)
                item.isHidden = true
            }
            // Hide trailing separators
            for item in fileMenu.items.reversed() {
                if item.isHidden { continue }
                if item.isSeparatorItem { item.isHidden = true } else { break }
            }
        }
    }

    private func closeCurrentAgent() {
        DispatchQueue.main.async { [weak self] in
            guard let manager = self?.agentManager,
                  let activeId = manager.activeAgentId,
                  let agent = manager.agents.first(where: { $0.id == activeId }) else {
                return
            }
            manager.removeAgent(agent)
        }
    }

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag && AppSettings.shared.keepInMenuBar {
            showMainWindow()
            return false
        }
        return true
    }

    func showMainWindow() {
        // Re-acquire window reference if lost (SwiftUI can recreate windows)
        if mainWindow == nil || mainWindow?.isReleasedWhenClosed == true {
            mainWindow = NSApp.windows.first(where: { $0.canBecomeMain })
        }

        guard let window = mainWindow else {
            print("[skwad] No main window reference!")
            return
        }

        // Show dock icon
        NSApp.setActivationPolicy(.regular)

        // Show window immediately
        window.orderFrontRegardless()

        // Activate after policy change has propagated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            window.makeKeyAndOrderFront(nil)
        }
    }

    func hideMainWindow() {
        // Acquire window reference if needed
        if mainWindow == nil {
            mainWindow = NSApp.windows.first(where: { $0.canBecomeMain })
        }

        // Hide window and remove dock icon
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func quitForReal() {
        isQuittingForReal = true
        NSApp.terminate(nil)
    }
}
