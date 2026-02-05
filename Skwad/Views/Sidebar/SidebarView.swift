import SwiftUI

struct SidebarView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var sidebarVisible: Bool
    @State private var showingNewAgentSheet = false
    @State private var agentToEdit: Agent?
    @State private var forkPrefill: AgentPrefill?
    @State private var showBroadcastSheet = false
    @State private var broadcastMessage = ""
    @State private var showRestartAllConfirmation = false
    @State private var showCloseAllConfirmation = false

    var body: some View {
        VStack() {
          
          VStack {
              HStack {
                Text(agentManager.currentWorkspace?.name.uppercased() ?? "AGENTS")
                  .font(.callout)
                  .fontWeight(.semibold)
                  .foregroundColor(Theme.secondaryText)

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
                  .help("Collapse sidebar")
              }
            }
            .frame(height: 32)
            .padding(.leading, 32)
            .padding(.trailing, 12)

            // Agent list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(agentManager.currentWorkspaceAgents) { agent in
                        AgentContextMenu(
                            agent: agent,
                            onEdit: { agentToEdit = agent },
                            onFork: {
                                forkPrefill = AgentPrefill(
                                    name: agent.name + " (fork)",
                                    avatar: agent.avatar,
                                    folder: agent.folder,
                                    agentType: agent.agentType,
                                    insertAfterId: agent.id
                                )
                            }
                        ) {
                            AgentRowView(agent: agent, isSelected: agent.id == agentManager.activeAgentId)
                                .onTapGesture {
                                    agentManager.selectAgent(agent.id)
                                }
                        }
                            .draggable(agent.id.uuidString) {
                                AgentRowView(agent: agent, isSelected: true)
                                    .frame(width: 200)
                                    .opacity(0.8)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                let workspaceAgents = agentManager.currentWorkspaceAgents
                                guard let droppedId = items.first,
                                      let droppedUUID = UUID(uuidString: droppedId),
                                      let fromIndex = workspaceAgents.firstIndex(where: { $0.id == droppedUUID }),
                                      let toIndex = workspaceAgents.firstIndex(where: { $0.id == agent.id }) else {
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
                
                Divider()
                
                Menu {
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
                } label: {
                    Label("Recent Agents", systemImage: "clock")
                }
            }

            // New agent button
            Button(action: { showingNewAgentSheet = true }) {
                Text("New Agent")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .focusable(false)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 200)
        .ignoresSafeArea()
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

    // MARK: - Recent Agents
    
    private func openRecentAgent(_ saved: SavedAgent) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: saved.folder, isDirectory: &isDirectory), isDirectory.boolValue else {
            settings.removeRecentAgent(saved)
            return
        }
        agentManager.addAgent(folder: saved.folder, name: saved.name, avatar: saved.avatar)
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

private func previewAgent(_ name: String, _ avatar: String, _ folder: String, status: AgentStatus = .idle, title: String = "") -> Agent {
    var agent = Agent(name: name, avatar: avatar, folder: folder)
    agent.status = status
    agent.terminalTitle = title
    return agent
}

#Preview("AgentRow") {
    VStack(spacing: 4) {
        AgentRowView(agent: previewAgent("skwad", "🐱", "/Users/nbonamy/src/skwad"), isSelected: false)
        AgentRowView(agent: previewAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .running, title: "Editing App.swift"), isSelected: true)
        AgentRowView(agent: previewAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error), isSelected: false)
    }
    .padding(8)
    .frame(width: 250)
}

@MainActor private func previewAgentManager() -> AgentManager {
    let m = AgentManager()
    let a1 = previewAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Editing ContentView.swift")
    let a2 = previewAgent("witsy", "🤖", "/Users/nbonamy/src/witsy")
    m.agents = [a1, a2]
    m.activeAgentIds = [a1.id]
    return m
}

#Preview("Sidebar") {
    SidebarView(sidebarVisible: .constant(true))
        .environment(previewAgentManager())
        .frame(width: 250, height: 500)
}
