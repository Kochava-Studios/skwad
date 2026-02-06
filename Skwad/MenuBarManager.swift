//
//  MenuBarManager.swift
//  Skwad
//
//  Manages the menu bar status item when "keep in menu bar" is enabled
//

import AppKit

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }

    func setup() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "seal.fill", accessibilityDescription: "Skwad")
            // Handle clicks manually to distinguish left/right
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click: show menu
            showContextMenu()
        } else {
            // Left click: show app
            appDelegate?.showMainWindow()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let quitItem = NSMenuItem(title: "Quit Skwad", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Clear menu so left click works again
        statusItem?.menu = nil
    }

    @objc private func quitApp() {
        appDelegate?.quitForReal()
    }
}
