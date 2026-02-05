import SwiftUI
import Logging
import Sparkle

// Global MCP server instance
private var mcpServerInstance: MCPServer?

@main
struct SkwadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var agentManager = AgentManager()
    private let updaterManager = UpdaterManager.shared
    @State private var mcpInitialized = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showBroadcastSheet = false
    @State private var broadcastMessage = ""
    @State private var showCloseConfirmation = false
    @State private var agentToClose: Agent?
    @State private var showNewAgentSheet = false
    @State private var showNewWorkspaceSheet = false
    @State private var toggleGitPanel = false
    @State private var toggleSidebar = false

    private var settings: AppSettings { AppSettings.shared }

    private var defaultOpenWithAppName: String? {
        guard !settings.defaultOpenWithApp.isEmpty else { return nil }
        return availableOpenWithApps.first { $0.id == settings.defaultOpenWithApp }?.name
    }

    private static let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init() {

        // preview mode
        guard !SkwadApp.isPreview else { return }
      
        // Initialize logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .info
            return handler
        }

        // Initialize source base folder on first launch
        AppSettings.shared.initializeSourceBaseFolderIfNeeded()

        // Start background repo discovery service
        RepoDiscoveryService.shared.start()

    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                showNewAgentSheet: $showNewAgentSheet,
                toggleGitPanel: $toggleGitPanel,
                toggleSidebar: $toggleSidebar
            )
                .environment(agentManager)
                .alert("Folder Not Found", isPresented: $showAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(alertMessage ?? "")
                }
                .sheet(isPresented: $showBroadcastSheet) {
                    BroadcastSheet(message: $broadcastMessage) { message in
                        broadcastToAllAgents(message)
                    }
                }
                .alert("Close Agent", isPresented: $showCloseConfirmation, presenting: agentToClose) { agent in
                    Button("Cancel", role: .cancel) {}
                    Button("Close", role: .destructive) {
                        agentManager.removeAgent(agent)
                    }
                } message: { agent in
                    Text("Are you sure you want to close \"\(agent.name)\"?")
                }
                .sheet(isPresented: $showNewWorkspaceSheet) {
                    WorkspaceSheet()
                        .environment(agentManager)
                }
                .onAppear {

                    // Skip initialization in previews
                    guard !SkwadApp.isPreview else { return }

                    // Only initialize once
                    guard !mcpInitialized else { return }
                    mcpInitialized = true

                    // Connect to app delegate for cleanup
                    appDelegate.agentManager = agentManager

                    // Setup menu bar if enabled
                    appDelegate.setupMenuBarIfNeeded()

                    // Apply appearance mode
                    AppSettings.shared.applyAppearance()

                    // Set agent manager reference in MCP service FIRST
                    Task {
                        await MCPService.shared.setAgentManager(agentManager)

                        // THEN start MCP server if enabled
                        if AppSettings.shared.mcpServerEnabled {
                            let port = AppSettings.shared.mcpServerPort
                            let server = MCPServer(port: port)
                            mcpServerInstance = server
                            appDelegate.mcpServer = server

                            do {
                                try await server.start()
                            } catch {
                                print("Failed to start MCP server: \(error)")
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            // File menu - workspace and agent creation (replacing removes default "New Window")
            CommandGroup(replacing: .newItem) {
                Button("New Workspace...") {
                    showNewWorkspaceSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Agent...") {
                    showNewAgentSheet = true
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                recentAgentsMenu

                Divider()

                Button("Broadcast to All Agents...") {
                    broadcastMessage = ""
                    showBroadcastSheet = true
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(agentManager.currentWorkspaceAgents.isEmpty)

                if let appName = defaultOpenWithAppName {
                    Divider()

                    Button("Open in \(appName)") {
                        openActiveAgentInDefaultApp()
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(agentManager.activeAgentId == nil)
                }
            }

            // Edit menu - text and terminal operations
            CommandGroup(after: .textEditing) {
                Divider()

                Button("Clear Agent") {
                    if let activeId = agentManager.activeAgentId {
                        agentManager.injectText("/clear", for: activeId)
                    }
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(agentManager.activeAgentId == nil)
            }

            // View menu - UI toggles
            CommandGroup(after: .sidebar) {
                Button("Toggle Git Panel") {
                    toggleGitPanel.toggle()
                }
                .keyboardShortcut("/", modifiers: .command)

                Button("Toggle Sidebar") {
                    toggleSidebar.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
            }

            // Window menu - agent navigation and management
            CommandGroup(after: .windowArrangement) {
                Button("Next Agent") {
                    agentManager.selectNextAgent()
                }
                .keyboardShortcut(KeyEquivalent.tab, modifiers: .control)

                Button("Previous Agent") {
                    agentManager.selectPreviousAgent()
                }
                .keyboardShortcut(KeyEquivalent.tab, modifiers: [.control, .shift])

                Divider()

                Button(agentManager.layoutMode == .single ? "Next Agent" : "Next Pane") {
                    agentManager.selectNextPaneOrAgent()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button(agentManager.layoutMode == .single ? "Previous Agent" : "Previous Pane") {
                    agentManager.selectPreviousPaneOrAgent()
                }
                .keyboardShortcut("[", modifiers: .command)

                Divider()

                Button("Restart Current Agent") {
                    if let agent = agentManager.agents.first(where: { $0.id == agentManager.activeAgentId }) {
                        agentManager.restartAgent(agent)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(agentManager.activeAgentId == nil)

                Divider()

                Button("Close Current Agent") {
                    closeCurrentAgent()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(agentManager.activeAgentId == nil)

                Button("Close Workspace") {
                    closeCurrentWorkspace()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(agentManager.currentWorkspace == nil)

                // Cmd+1-9 to switch workspaces
                if !agentManager.workspaces.isEmpty {
                    Divider()

                    ForEach(Array(agentManager.workspaces.enumerated().prefix(9)), id: \.element.id) { index, workspace in
                        Button(workspace.name) {
                            agentManager.switchToWorkspace(workspace.id)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    }
                }

                // Ctrl+1-9 to select agents within workspace
                if !agentManager.currentWorkspaceAgents.isEmpty {
                    Divider()

                    ForEach(Array(agentManager.currentWorkspaceAgents.enumerated().prefix(9)), id: \.element.id) { index, agent in
                        Button(agent.name) {
                            agentManager.selectAgentAtIndex(index)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .control)
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterManager.updater)
            }
        }
    }

    @ViewBuilder
    private var recentAgentsMenu: some View {
        Menu("Recent Agents") {
            if settings.recentAgents.isEmpty {
                Button("No Recent Agents") {}
                    .disabled(true)
            } else {
                ForEach(settings.recentAgents) { agent in
                    Button {
                        openRecentAgent(agent)
                    } label: {
                        Text("\(agent.name) — \(URL(fileURLWithPath: agent.folder).lastPathComponent)")
                    }
                }

                Divider()

                Button("Clear Recent Agents") {
                    settings.recentAgents = []
                }
            }
        }
    }

    private func openRecentAgent(_ saved: SavedAgent) {
        // Check if folder still exists
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: saved.folder, isDirectory: &isDirectory), isDirectory.boolValue else {
            // Folder doesn't exist - remove from recent and alert
            settings.removeRecentAgent(saved)
            alertMessage = "The folder \"\(saved.folder)\" no longer exists."
            showAlert = true
            return
        }

        // Add the agent
        agentManager.addAgent(folder: saved.folder, name: saved.name, avatar: saved.avatar)
    }

    private func broadcastToAllAgents(_ message: String) {
        guard !message.isEmpty else { return }

        // Inject message into all agents in current workspace (injectText includes return)
        for agent in agentManager.currentWorkspaceAgents {
            agentManager.injectText(message, for: agent.id)
        }
    }

    private func closeCurrentAgent() {
        guard let agent = agentManager.agents.first(where: { $0.id == agentManager.activeAgentId }) else {
            return
        }

        // Remove the agent without confirmation
        agentManager.removeAgent(agent)
    }

    private func closeCurrentWorkspace() {
        guard let workspace = agentManager.currentWorkspace else { return }
        agentManager.removeWorkspace(workspace)
    }

    private func openActiveAgentInDefaultApp() {
        guard let agent = agentManager.agents.first(where: { $0.id == agentManager.activeAgentId }) else {
            return
        }
        OpenWithProvider.open(agent.folder, withAppId: settings.defaultOpenWithApp)
    }
}

// MARK: - Broadcast Sheet

struct BroadcastSheet: View {
    @Binding var message: String
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Broadcast to All Agents")
                .font(.headline)

            Text("Send the same message to all agents simultaneously.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $message)
                .font(.system(size: 16))
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Send") {
                    onSend(message)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
