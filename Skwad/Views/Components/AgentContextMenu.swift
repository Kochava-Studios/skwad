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
            Label {
                Text(title)
            } icon: {
                Image(nsImage: image.resized(to: NSSize(width: 16, height: 16)))
            }
        } else if let fallback = fallback {
            Label(title, systemImage: fallback)
        } else {
            Text(title)
        }
    }
}

/// Reusable agent context menu builder
struct AgentContextMenu<Content: View>: View {
    let agent: Agent
    let onEdit: () -> Void
    let onFork: () -> Void
    @ViewBuilder let content: Content

    @Environment(AgentManager.self) var agentManager

    var body: some View {
        content.contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Agent...", systemImage: "pencil")
            }

            Button {
                onFork()
            } label: {
                Label("Fork Agent", systemImage: "arrow.triangle.branch")
            }

            Button {
                agentManager.duplicateAgent(agent)
            } label: {
                Label("Duplicate Agent", systemImage: "plus.square.on.square")
            }

            // Move to Workspace submenu (only show if there are other workspaces)
            if agentManager.workspaces.count > 1 {
                Menu {
                    ForEach(agentManager.workspaces.filter { $0.id != agentManager.currentWorkspaceId }) { workspace in
                        Button {
                            agentManager.moveAgentToWorkspace(agent, to: workspace.id)
                        } label: {
                            Label(workspace.name, systemImage: "square.stack")
                        }
                    }
                } label: {
                    Label("Move to Workspace", systemImage: "arrow.right.square")
                }
            }

            Divider()

            Menu {
                ForEach(OpenWithProvider.menuElements()) { element in
                    switch element {
                    case .app(let app):
                        Button {
                            OpenWithProvider.open(agent.folder, with: app)
                        } label: {
                            IconLabel(app.name, icon: app.icon ?? "", fallback: app.systemIcon)
                        }
                    case .separator:
                        Divider()
                    }
                }
            } label: {
                Label("Open In...", systemImage: "arrow.up.forward.app")
            }

            // Markdown files history submenu
            if !agent.markdownFileHistory.isEmpty {
                Menu {
                    ForEach(agent.markdownFileHistory, id: \.self) { filePath in
                        Button {
                            agentManager.showMarkdownPanel(filePath: filePath, forAgent: agent.id)
                        } label: {
                            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                        }
                    }
                } label: {
                    Label("Markdown Files", systemImage: "doc.text")
                }
            }

            Divider()

            Button {
                agentManager.registerAgent(agent)
            } label: {
                Label("Register Agent", systemImage: "person.badge.plus")
            }

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
    }
}
