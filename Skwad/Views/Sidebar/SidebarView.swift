import SwiftUI

/// Label with custom icon from assets, with SF Symbol fallback
struct IconLabel: View {
    let title: String
    let icon: String
    let fallback: String?

    init(_ title: String, icon: String, fallback: String? = nil) {
        self.title = title
        self.icon = icon
        self.fallback = fallback
    }

    var body: some View {
        if let image = NSImage(named: icon) {
            // Resize the NSImage before creating the SwiftUI Image
            let resized = resizeImage(image, to: NSSize(width: 16, height: 16))
            Label {
                Text(title)
            } icon: {
                Image(nsImage: resized)
            }
        } else if let fallback = fallback {
            Label(title, systemImage: fallback)
        } else {
            Text(title)
        }
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

struct SidebarView: View {
    @EnvironmentObject var agentManager: AgentManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingNewAgentSheet = false
    @State private var agentToEdit: Agent?
    @State private var forkPrefill: AgentPrefill?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("SKWAD")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.secondaryText)
                .padding(.horizontal, 16)
                .padding(.top, 52)
                .padding(.bottom, 8)

            // Agent list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(agentManager.agents) { agent in
                        AgentRowView(agent: agent, isSelected: agentManager.selectedAgentId == agent.id)
                            .onTapGesture {
                                agentManager.selectedAgentId = agent.id
                            }
                            .contextMenu {
                                Button {
                                    agentToEdit = agent
                                } label: {
                                    Label("Edit Agent...", systemImage: "pencil")
                                }

                                Button {
                                    forkPrefill = AgentPrefill(
                                        name: agent.name + " (fork)",
                                        avatar: agent.avatar,
                                        folder: agent.folder,
                                        agentType: agent.agentType,
                                        insertAfterId: agent.id
                                    )
                                } label: {
                                    Label("Fork Agent", systemImage: "arrow.triangle.branch")
                                }

                                Button {
                                    agentManager.duplicateAgent(agent)
                                } label: {
                                    Label("Duplicate Agent", systemImage: "plus.square.on.square")
                                }

                                Divider()

                                Menu {
                                    Button {
                                        openInIDE(agent.folder, ide: "vscode")
                                    } label: {
                                        IconLabel("VS Code", icon: "vscode")
                                    }
                                    Button {
                                        openInIDE(agent.folder, ide: "xcode")
                                    } label: {
                                        IconLabel("Xcode", icon: "xcode")
                                    }
                                    Divider()
                                    Button {
                                        openInFinder(agent.folder)
                                    } label: {
                                        IconLabel("Finder", icon: "finder", fallback: "folder")
                                    }
                                    Button {
                                        openInTerminal(agent.folder)
                                    } label: {
                                        IconLabel("Terminal", icon: "ghostty", fallback: "terminal")
                                    }
                                } label: {
                                    Label("Open In...", systemImage: "arrow.up.forward.app")
                                }

                                Divider()

                                Button {
                                    agentManager.restartAgent(agent)
                                } label: {
                                    Label("Restart Agent", systemImage: "arrow.clockwise")
                                }

                                Button(role: .destructive) {
                                    agentManager.removeAgent(agent)
                                } label: {
                                    Label("Close Agent", systemImage: "xmark.circle")
                                }
                            }
                            .draggable(agent.id.uuidString) {
                                AgentRowView(agent: agent, isSelected: true)
                                    .frame(width: 200)
                                    .opacity(0.8)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let droppedId = items.first,
                                      let droppedUUID = UUID(uuidString: droppedId),
                                      let fromIndex = agentManager.agents.firstIndex(where: { $0.id == droppedUUID }),
                                      let toIndex = agentManager.agents.firstIndex(where: { $0.id == agent.id }) else {
                                    return false
                                }
                                if fromIndex != toIndex {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
                                        agentManager.moveAgent(from: IndexSet(integer: fromIndex), to: destination)
                                    }
                                }
                                return true
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()
                .background(Theme.secondaryText.opacity(0.3))

            // New agent button
            Button(action: { showingNewAgentSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title3)
                    Text("New Agent")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                .foregroundColor(Theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .frame(minWidth: 200)
        .background(settings.sidebarBackgroundColor)
        .sheet(isPresented: $showingNewAgentSheet) {
            AgentSheet()
        }
        .sheet(item: $forkPrefill) { prefill in
            AgentSheet(prefill: prefill)
        }
        .sheet(item: $agentToEdit) { agent in
            AgentSheet(editing: agent)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNewAgentSheet)) { _ in
            showingNewAgentSheet = true
        }
    }

    // MARK: - Open In IDE

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
}

extension Notification.Name {
    static let showNewAgentSheet = Notification.Name("showNewAgentSheet")
}

struct AgentRowView: View {
    let agent: Agent
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(avatar: agent.avatar, size: 40, font: .largeTitle)

            VStack(alignment: .leading, spacing: 0) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(agent.displayTitle.isEmpty ? "Ready" : agent.displayTitle)
                    .font(.callout)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)

              Text(URL(fileURLWithPath: agent.folder).lastPathComponent)
                    .font(.callout)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(agent.status.color)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Theme.selectionBackground : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Theme.selectionBorder : Color.clear, lineWidth: 1)
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
