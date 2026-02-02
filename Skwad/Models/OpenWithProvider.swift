import AppKit

/// Available "Open With" applications
let availableOpenWithApps: [OpenWithApp] = [
    OpenWithApp("vscode", "VS Code", icon: "vscode"),
    OpenWithApp("xcode", "Xcode", icon: "xcode"),
    OpenWithApp("finder", "Finder", icon: "finder", systemIcon: "folder"),
    OpenWithApp("terminal", "Terminal", icon: "ghostty", systemIcon: "terminal"),
]

/// Provides the list of "Open With" menu items for a given folder
struct OpenWithProvider {
    /// Returns the list of menu elements (apps and separators) for the "Open With" menu
    static func menuElements() -> [MenuElement] {
        return [
            .app(availableOpenWithApps[0]), // VS Code
            .app(availableOpenWithApps[1]), // Xcode
            .separator,
            .app(availableOpenWithApps[2]), // Finder
            .app(availableOpenWithApps[3]), // Terminal
        ]
    }

    /// Opens the folder in the specified app
    static func open(_ folder: String, with app: OpenWithApp) {
        switch app.id {
        case "vscode":
            openInIDE(folder, ide: "vscode")
        case "xcode":
            openInIDE(folder, ide: "xcode")
        case "finder":
            openInFinder(folder)
        case "terminal":
            openInTerminal(folder)
        default:
            break
        }
    }

    /// Opens the folder with the app matching the given ID
    static func open(_ folder: String, withAppId appId: String) {
        guard let app = availableOpenWithApps.first(where: { $0.id == appId }) else { return }
        open(folder, with: app)
    }
}

// MARK: - Helper Functions

private func openInIDE(_ folder: String, ide: String) {
    switch ide {
    case "vscode":
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", "com.microsoft.VSCode", folder]
        try? process.run()

    case "xcode":
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Xcode", folder]
        try? process.run()

    default:
        break
    }
}

private func openInFinder(_ folder: String) {
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder)
}

private func openInTerminal(_ folder: String) {
    // Try Ghostty first, fall back to Terminal.app
    let ghosttyBundleId = "com.mitchellh.ghostty"
    let terminalBundleId = "com.apple.Terminal"

    let bundleId = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ghosttyBundleId) != nil
        ? ghosttyBundleId
        : terminalBundleId

    if bundleId == ghosttyBundleId {
        // Ghostty: just open the folder, it will start a shell there
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", ghosttyBundleId, folder]
        try? process.run()
    } else {
        // Terminal.app: use AppleScript to cd into folder
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(folder)'"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
