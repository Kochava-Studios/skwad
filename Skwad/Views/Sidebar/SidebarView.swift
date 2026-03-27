import SwiftUI

struct SidebarView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var sidebarVisible: Bool
    @Binding var forkPrefill: AgentPrefill?
    var isCompact: Bool = false
    @State private var showingNewAgentSheet = false
    @State private var agentToEdit: Agent?
    @State private var showBroadcastSheet = false
    @State private var broadcastMessage = ""
    @State private var showRestartAllConfirmation = false
    @State private var showCloseAllConfirmation = false
    @State private var draggedAgentId: UUID?
    @State private var dropTargetAgentId: UUID?
    @State private var dropPosition: DropPosition = .above

    var body: some View {
        VStack() {
          
          VStack {
              HStack {
                if !isCompact {
                  HeaderTitleView(title: agentManager.currentWorkspace?.name ?? "Agents")
                }

                Spacer()

                  Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                      sidebarVisible = false
                    }
                  } label: {
                    Image(systemName: "sidebar.left")
                      .font(.system(size: 12))
                      .foregroundColor(Theme.secondaryText)
                  }
                  .buttonStyle(.plain)
                  .focusEffectDisabled()
                  .help("Collapse sidebar")
              }
            }
            .frame(height: 32)
            .padding(.leading, isCompact ? 12 : 32)
            .padding(.trailing, 12)

            // Agent list
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Overview row
                    overviewRow

                    ForEach(agentManager.currentWorkspaceAgents.filter { !$0.isCompanion }) { agent in
                        AgentContextMenu(
                            agent: agent,
                            onEdit: { agentToEdit = agent },
                            onFork: {
                                forkPrefill = agent.forkPrefill()
                            },
                            onNewCompanion: {
                                forkPrefill = agent.companionPrefill()
                            },
                            onShellCompanion: {
                                agentManager.createShellCompanion(for: agent)
                            },
                            onSaveToBench: {
                                settings.addToBench(agent)
                            }
                        ) {
                            AgentRowView(
                                agent: agent,
                                isSelected: agentManager.isAgentActive(agent.id),
                                companions: agentManager.companions(of: agent.id),
                                isCompact: isCompact
                            )
                            .onTapGesture {
                                let cmdHeld = NSEvent.modifierFlags.contains(.command)
                                agentManager.selectAgent(agent.id, skipCompanionLayout: cmdHeld)
                            }
                        }
                            .overlay(alignment: .top) {
                                if dropTargetAgentId == agent.id && dropPosition == .above {
                                    DropIndicatorLine()
                                        .offset(y: -3)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if dropTargetAgentId == agent.id && dropPosition == .below {
                                    DropIndicatorLine()
                                        .offset(y: 3)
                                }
                            }
                            .onDrag {
                                draggedAgentId = agent.id
                                return NSItemProvider(object: agent.id.uuidString as NSString)
                            } preview: {
                                AgentRowView(agent: agent, isSelected: true)
                                    .frame(width: 200)
                                    .opacity(0.8)
                            }
                            .dropDestination(for: String.self) { items, location in
                                let position = dropPosition
                                dropTargetAgentId = nil
                                return handleDrop(items: items, targetAgentId: agent.id, position: position)
                            } isTargeted: { isTargeted in
                                if isTargeted {
                                    dropTargetAgentId = agent.id
                                    // Determine above/below from source vs target position
                                    if let agentIds = agentManager.currentWorkspace?.agentIds,
                                       let targetIndex = agentIds.firstIndex(of: agent.id),
                                       let draggedId = draggedAgentId,
                                       let fromIndex = agentIds.firstIndex(of: draggedId) {
                                        dropPosition = fromIndex < targetIndex ? .below : .above
                                    }
                                } else if dropTargetAgentId == agent.id {
                                    dropTargetAgentId = nil
                                }
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .contextMenu {
                Button {
                    showingNewAgentSheet = true
                } label: {
                    Label("New Agent", systemImage: "plus.app")
                }
                
                Button {
                    showRestartAllConfirmation = true
                } label: {
                    Label("Restart All", systemImage: "arrow.clockwise")
                }
                .disabled(agentManager.currentWorkspaceAgents.isEmpty)

                Button {
                    showCloseAllConfirmation = true
                } label: {
                    Label("Close All", systemImage: "xmark.circle")
                }
                .disabled(agentManager.currentWorkspaceAgents.isEmpty)

                Divider()

                Button {
                    broadcastMessage = ""
                    showBroadcastSheet = true
                } label: {
                    Label("Broadcast to All Agents...", systemImage: "megaphone")
                }
                .disabled(agentManager.currentWorkspaceAgents.isEmpty)
                
            }

            // Conversation history for selected agent
            if !isCompact, let agent = agentManager.selectedAgent, ConversationHistoryService.shared.supportsHistory(agentType: agent.agentType) {
                ConversationHistoryView(agent: agent)
            }

            // New agent button with bench dropdown
            if isCompact {
                Button {
                    showingNewAgentSheet = true
                } label: {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            } else {
                SplitButton("New Agent") {
                    showingNewAgentSheet = true
                } popover: {
                    BenchDropdownView(
                        onNewAgent: {
                            showingNewAgentSheet = true
                        },
                        onDeploy: { benchAgent in
                            agentManager.deployBenchAgent(benchAgent)
                        }
                    )
                    .environment(agentManager)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 64)
        .ignoresSafeArea()
        .background(settings.sidebarBackgroundColor)
        .sheet(isPresented: $showingNewAgentSheet) {
            AgentSheet()
        }
        .sheet(item: $agentToEdit) { agent in
            AgentSheet(editing: agent)
        }
        .sheet(isPresented: $showBroadcastSheet) {
            BroadcastSheet(message: $broadcastMessage) { message in
                sendBroadcast(message)
            }
        }
        .alert("Restart All Agents", isPresented: $showRestartAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restart All", role: .destructive) {
                restartAllAgents()
            }
        } message: {
            Text("Are you sure you want to restart all \(agentManager.currentWorkspaceAgents.count) agent(s)?")
        }
        .alert("Close All Agents", isPresented: $showCloseAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Close All", role: .destructive) {
                closeAllAgents()
            }
        } message: {
            Text("Are you sure you want to close all \(agentManager.currentWorkspaceAgents.count) agent(s)?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .showNewAgentSheet)) { _ in
            showingNewAgentSheet = true
        }
    }

    // MARK: - Overview Row

    private var overviewRow: some View {
        Group {
            if isCompact {
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .foregroundColor(agentManager.showDashboard ? Theme.primaryText : Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(agentManager.showDashboard ? Theme.selectionBackground : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(agentManager.showDashboard ? Theme.selectionBorder : Color.primary.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(8)
                .contentShape(Rectangle())
                .help("Dashboard")
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .foregroundColor(agentManager.showDashboard ? Theme.primaryText : Theme.secondaryText)
                        .frame(width: 40, height: 40)

                    Text("Dashboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(agentManager.showDashboard ? Theme.primaryText : Theme.secondaryText)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(agentManager.showDashboard ? Theme.selectionBackground : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(agentManager.showDashboard ? Theme.selectionBorder : Color.primary.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(8)
                .contentShape(Rectangle())
            }
        }
        .padding(.bottom, 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                agentManager.showDashboard.toggle()
            }
        }
    }

    // MARK: - Drag and Drop

    private func handleDrop(items: [String], targetAgentId: UUID, position: DropPosition) -> Bool {
        defer { draggedAgentId = nil }
        guard let droppedId = items.first,
              let droppedUUID = UUID(uuidString: droppedId),
              let agentIds = agentManager.currentWorkspace?.agentIds,
              let fromIndex = agentIds.firstIndex(of: droppedUUID),
              let toIndex = agentIds.firstIndex(of: targetAgentId) else {
            return false
        }
        if fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.15)) {
                let destination: Int
                if position == .below {
                    destination = toIndex > fromIndex ? toIndex + 1 : toIndex + 1
                } else {
                    destination = toIndex > fromIndex ? toIndex : toIndex
                }
                agentManager.moveAgent(from: IndexSet(integer: fromIndex), to: destination)
            }
        }
        return true
    }

    // MARK: - Broadcast

    private func sendBroadcast(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Inject message into all agents in current workspace
        for agent in agentManager.currentWorkspaceAgents {
            agentManager.injectText(trimmed, for: agent.id)
        }
    }
    
    // MARK: - Restart All
    
    private func restartAllAgents() {
        // Restart all agents in current workspace
        let agentsToRestart = agentManager.currentWorkspaceAgents
        for agent in agentsToRestart {
            agentManager.restartAgent(agent)
        }
    }

    // MARK: - Close All

    private func closeAllAgents() {
        // Remove all agents in current workspace
        let agentsToClose = agentManager.currentWorkspaceAgents
        for agent in agentsToClose {
            agentManager.removeAgent(agent)
        }
    }

}

extension Notification.Name {
    static let showNewAgentSheet = Notification.Name("showNewAgentSheet")
}

// MARK: - Drag and Drop

enum DropPosition {
    case above, below
}

struct DropIndicatorLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
        }
        .padding(.horizontal, 4)
    }
}

struct AgentRowView: View {
    let agent: Agent
    let isSelected: Bool
    var companions: [Agent] = []
    var isCompact: Bool = false

    var body: some View {
        if isCompact {
            compactBody
        } else {
            normalBody
        }
    }

    var compactBody: some View {
        VStack(spacing: 4) {
            // Avatar with status dot overlay
            ZStack(alignment: .bottomTrailing) {
                AvatarView(avatar: agent.avatar, size: 40, font: .largeTitle)

                if !agent.isShell {
                    Circle()
                        .fill(agent.state.color)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.3), lineWidth: 1)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 40, height: 40)

            // Compact companion avatars (no names)
            if !companions.isEmpty {
                HStack(spacing: 3) {
                    ForEach(companions) { companion in
                        ZStack(alignment: .bottomTrailing) {
                            AvatarView(avatar: companion.avatar, size: 18, font: .caption2)

                            if !companion.isShell {
                                Circle()
                                    .fill(companion.state.color)
                                    .frame(width: 6, height: 6)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5)
                                    )
                                    .offset(x: 1, y: 1)
                            }
                        }
                        .frame(width: 18, height: 18)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isSelected ? Theme.selectionBackground : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Theme.selectionBorder : Color.clear, lineWidth: 1)
        )
        .cornerRadius(8)
        .contentShape(Rectangle())
        .help(agent.name)
    }

    var normalBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AvatarView(avatar: agent.avatar, size: 40, font: .largeTitle)

                VStack(alignment: .leading, spacing: 0) {
                    Text(agent.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    if let personaName = AppSettings.shared.persona(for: agent.personaId)?.name {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            Text(personaName)
                                .lineLimit(1)
                        }
                        .font(.callout)
                        .foregroundColor(Theme.secondaryText)
                    }

                    Text(agent.displayTitle.isEmpty ? "Ready" : agent.displayTitle)
                        .font(.callout)
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if agent.workingFolder != agent.folder {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundColor(Theme.secondaryText)
                        }
                        Text(URL(fileURLWithPath: agent.workingFolder).lastPathComponent)
                            .font(.callout)
                            .foregroundColor(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !agent.isShell {
                    Circle()
                        .fill(agent.state.color)
                        .frame(width: 8, height: 8)
                }
            }

            if !companions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(companions) { companion in
                        HStack(spacing: 6) {
                            AvatarView(avatar: companion.avatar, size: 14, font: .caption2)
                            Text(companion.name)
                                .font(.caption)
                                .foregroundColor(Theme.secondaryText)
                                .lineLimit(1)
                            Spacer()
                            if !companion.isShell {
                                Circle()
                                    .fill(companion.state.color)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 52)
            }
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

#Preview("AgentRow") {
    VStack(spacing: 4) {
        AgentRowView(agent: previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad"), isSelected: false)
        AgentRowView(agent: previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .running, title: "Editing App.swift"), isSelected: true)
        AgentRowView(agent: previewDashboardAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error), isSelected: false)
    }
    .padding(8)
    .frame(width: 250)
}

#Preview("AgentRow Compact") {
    VStack(spacing: 4) {
        AgentRowView(agent: previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad"), isSelected: false, isCompact: true)
        AgentRowView(agent: previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .running, title: "Editing App.swift"), isSelected: true, isCompact: true)
        AgentRowView(agent: previewDashboardAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error), isSelected: false, isCompact: true)
    }
    .padding(8)
    .frame(width: 80)
}

@MainActor private func previewAgentManager() -> AgentManager {
    let m = AgentManager()
    let a1 = previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Editing ContentView.swift")
    let a2 = previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy")
    let a3 = previewDashboardAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error)
    m.agents = [a1, a2, a3]
    let workspace = Workspace(name: "Preview", colorHex: WorkspaceColor.blue.rawValue, agentIds: [a1.id, a2.id, a3.id])
    m.workspaces = [workspace]
    m.currentWorkspaceId = workspace.id
    m.activeAgentIds = [a1.id]
    return m
}

#Preview("Sidebar") {
    SidebarView(sidebarVisible: .constant(true), forkPrefill: .constant(nil))
        .environment(previewAgentManager())
        .frame(width: 250, height: 500)
}

#Preview("Sidebar Compact") {
    SidebarView(sidebarVisible: .constant(true), forkPrefill: .constant(nil), isCompact: true)
        .environment(previewAgentManager())
        .frame(width: 80, height: 500)
}
