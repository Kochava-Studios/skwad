import SwiftUI

extension Notification.Name {
    static let closeWorkspace = Notification.Name("closeWorkspace")
}

struct WorkspaceBarView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Binding var sidebarVisible: Bool

    @State private var showingNewWorkspaceSheet = false
    @State private var workspaceToEdit: Workspace?
    @State private var workspaceToClose: Workspace?

    private var backgroundColor: Color {
        // In previews, use SwiftUI color scheme
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return colorScheme == .dark
                ? Color(white: 0.15)
                : Color(white: 0.90)
        }
        // Use full sidebar color when sidebar is hidden for contrast
        return sidebarVisible
            ? settings.sidebarBackgroundColor.withAddedContrast(by: 0.03)
            : settings.sidebarBackgroundColor
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Spacer(minLength: 32)

                // Workspace list
                ForEach(agentManager.workspaces) { workspace in
                    WorkspaceAvatarView(
                        workspace: workspace,
                        isSelected: workspace.id == agentManager.currentWorkspaceId,
                        activityStatus: agentManager.workspaceStatus(workspace)
                    )
                    .onTapGesture {
                        agentManager.switchToWorkspace(workspace.id)
                    }
                    .contextMenu {
                        Button {
                            workspaceToEdit = workspace
                        } label: {
                            Label("Edit Workspace...", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            workspaceToClose = workspace
                        } label: {
                            Label("Close Workspace", systemImage: "xmark.circle")
                        }
                    }
                    .draggable(workspace.id.uuidString) {
                        WorkspaceAvatarView(
                            workspace: workspace,
                            isSelected: true,
                            activityStatus: nil
                        )
                        .opacity(0.8)
                    }
                    .dropDestination(for: String.self) { items, _ in
                        guard let droppedId = items.first,
                              let droppedUUID = UUID(uuidString: droppedId),
                              let fromIndex = agentManager.workspaces.firstIndex(where: { $0.id == droppedUUID }),
                              let toIndex = agentManager.workspaces.firstIndex(where: { $0.id == workspace.id }) else {
                            return false
                        }
                        if fromIndex != toIndex {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                let destination = toIndex > fromIndex ? toIndex + 1 : toIndex
                                agentManager.moveWorkspace(from: IndexSet(integer: fromIndex), to: destination)
                            }
                        }
                        return true
                    }
                }

                // Add workspace button
                Button(action: { showingNewWorkspaceSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: 52)
        .background(backgroundColor)
        .sheet(isPresented: $showingNewWorkspaceSheet) {
            WorkspaceSheet()
        }
        .sheet(item: $workspaceToEdit) { workspace in
            WorkspaceSheet(workspace: workspace)
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeWorkspace)) { notification in
            if let workspace = notification.object as? Workspace {
                workspaceToClose = workspace
            }
        }
        .alert("Close Workspace", isPresented: Binding(
            get: { workspaceToClose != nil },
            set: { if !$0 { workspaceToClose = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                workspaceToClose = nil
            }
            Button("Close", role: .destructive) {
                if let workspace = workspaceToClose {
                    agentManager.removeWorkspace(workspace)
                }
                workspaceToClose = nil
            }
        } message: {
            if let workspace = workspaceToClose {
                let count = workspace.agentIds.count
                if count > 0 {
                    Text("This will close \(count) agent\(count == 1 ? "" : "s") in \"\(workspace.name)\".")
                } else {
                    Text("Close workspace \"\(workspace.name)\"?")
                }
            }
        }
    }
}

// MARK: - Workspace Avatar View

struct WorkspaceAvatarView: View {
    let workspace: Workspace
    let isSelected: Bool
    let activityStatus: AgentStatus?

    private let size: CGFloat = 32
    private let unselectedColor = Color(hex: "#848CAF")!

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(isSelected ? workspace.color : unselectedColor)
                .frame(width: size, height: size)
                .overlay(
                    Text(workspace.initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Activity indicator dot (color reflects workspace status)
            if let status = activityStatus {
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size, height: size)
        .help(workspace.name)
    }
}

// Preview helper to create a populated AgentManager
@MainActor
private func previewAgentManager() -> AgentManager {
    let manager = AgentManager()
    manager.workspaces = [
        Workspace(name: "Skwad", colorHex: WorkspaceColor.blue.rawValue),
        Workspace(name: "My Project", colorHex: WorkspaceColor.purple.rawValue),
        Workspace(name: "Work", colorHex: WorkspaceColor.green.rawValue),
        Workspace(name: "Side Project", colorHex: WorkspaceColor.orange.rawValue),
    ]
    manager.currentWorkspaceId = manager.workspaces[0].id
    return manager
}

#Preview {
    HStack(spacing: 0) {
        WorkspaceBarView(sidebarVisible: .constant(true))
            .environment(previewAgentManager())

        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor))
            .frame(width: 200)
    }
    .frame(height: 400)
}
