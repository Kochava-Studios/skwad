import SwiftUI

struct DashboardView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var forkPrefill: AgentPrefill?
    @State private var sort: DashboardSort = .manual
    @State private var agentToEdit: Agent?
    @State private var now = Date()
    @State private var containerWidth: CGFloat = 0

    /// Optional: show only this workspace. nil = show all workspaces.
    let workspaceId: UUID?

    private var workspaces: [Workspace] {
        if let workspaceId, let ws = agentManager.workspaces.first(where: { $0.id == workspaceId }) {
            return [ws]
        }
        return agentManager.workspaces
    }

    private var isGlobal: Bool { workspaceId == nil }

    private var headerTitle: String {
        if let workspaceId, let ws = agentManager.workspaces.first(where: { $0.id == workspaceId }) {
            return ws.name
        }
        return "Command Center"
    }

    private var headerAgents: [Agent] {
        if let workspaceId {
            return agentManager.agents.filter { agent in
                agentManager.workspaces.first(where: { $0.id == workspaceId })?.agentIds.contains(agent.id) == true
            }
        }
        return agentManager.agents
    }

    /// Max agent count (+1 for add card) across displayed workspaces, so all sections share the same grid width.
    private var maxItemCount: Int {
        let counts = workspaces.map { workspace in
            workspace.agentIds.filter { id in
                agentManager.agents.contains { $0.id == id && !$0.isCompanion }
            }.count
        }
        return (counts.max() ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (integrated in window title bar)
            HStack(spacing: 12) {
                HeaderTitleView(title: headerTitle)

                Spacer()

                StatusSummaryView(agents: headerAgents)
            }
            .frame(height: 32)
            .padding(.leading, 32)
            .padding(.trailing, 16)
            .background(settings.sidebarBackgroundColor)

            // Workspace sections
            GeometryReader { geo in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(workspaces) { workspace in
                            workspaceSection(workspace)
                        }
                    }
                    .frame(width: DashboardMetrics.gridWidth(for: geo.size.width, itemCount: maxItemCount))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 64)
                    .padding(.bottom, 24)
                }
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newValue in containerWidth = newValue }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.effectiveBackgroundColor)
        .overlay(alignment: .topTrailing) {
            DashboardSortPicker(sort: $sort)
                .padding(.top, 40)
                .padding(.trailing, 16)
        }
        .sheet(item: $agentToEdit) { agent in
            AgentSheet(editing: agent)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    // MARK: - Workspace Section

    private func workspaceSection(_ workspace: Workspace) -> some View {
        let workspaceAgents = sort.sorted(workspace.agentIds.compactMap { id in
            agentManager.agents.first { $0.id == id }
        }.filter { !$0.isCompanion })

        return VStack(alignment: .leading, spacing: 12) {
            // Workspace header with color bar
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(workspace.color)
                    .frame(width: 4, height: 24)

                if isGlobal {
                    Button {
                        navigateToWorkspaceDashboard(workspace)
                    } label: {
                        Text(workspace.name)
                            .font(.title2.bold())
                            .foregroundColor(Theme.primaryText)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(workspace.name)
                        .font(.title2.bold())
                        .foregroundColor(Theme.primaryText)
                }

                StatusSummaryView(agents: workspaceAgents)

                Spacer()

                if lastRowIsFull(workspaceAgents.count) {
                    Button { addAgent(to: workspace) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.secondaryText)
                            Text("Add Agent")
                        }.opacity(0.8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Agent cards grid
            if workspaceAgents.isEmpty {
                Text("No agents")
                    .font(.callout)
                    .foregroundColor(Theme.secondaryText)
                    .padding(.leading, 14)
            } else {
                DashboardAgentGrid(
                    forkPrefill: $forkPrefill,
                    agentToEdit: $agentToEdit,
                    agents: workspaceAgents,
                    now: now,
                    onAgentTap: { agent in navigateToAgent(agent, in: workspace) },
                    onAddAgent: { addAgent(to: workspace) }
                )
            }
        }
    }

    private func gridColumnCount() -> Int {
        let gridWidth = DashboardMetrics.gridWidth(for: containerWidth, itemCount: maxItemCount)
        return max(1, Int((gridWidth + DashboardMetrics.gridSpacing) / (DashboardMetrics.cardWidth + DashboardMetrics.gridSpacing)))
    }

    private func lastRowIsFull(_ agentCount: Int) -> Bool {
        agentCount > 0 && agentCount % gridColumnCount() == 0
    }

    // MARK: - Actions

    private func addAgent(to workspace: Workspace) {
        let folder = workspace.agentIds.compactMap { id in
            agentManager.agents.first { $0.id == id }
        }.first?.folder ?? ""
        forkPrefill = AgentPrefill(name: "", avatar: nil, folder: folder, agentType: "claude", insertAfterId: workspace.agentIds.last)
    }

    // MARK: - Navigation

    private func navigateToWorkspaceDashboard(_ workspace: Workspace) {
        withAnimation(.easeInOut(duration: 0.25)) {
            agentManager.showGlobalDashboard = false
            agentManager.switchToWorkspace(workspace.id)
            agentManager.showDashboard = true
        }
    }

    private func navigateToAgent(_ agent: Agent, in workspace: Workspace) {
        // Batch all state changes in a single animation transaction so the
        // terminal header doesn't animate separately from the dashboard fade
        withAnimation(.easeInOut(duration: 0.25)) {
            if isGlobal {
                agentManager.showGlobalDashboard = false
                agentManager.switchToWorkspace(workspace.id)
            } else {
                agentManager.showDashboard = false
            }
            agentManager.selectAgent(agent.id)
        }
    }
}

// MARK: - Previews

@MainActor private func previewGlobalDashboardManager() -> AgentManager {
    let m = AgentManager()

    let agents1 = [
        previewDashboardAgent("skwad", "🐱", "/src/skwad", status: .running, title: "Building dashboard", gitStats: .init(insertions: 156, deletions: 12, files: 5)),
        previewDashboardAgent("witsy", "🤖", "/src/witsy", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),
    ]
    let agents2 = [
        previewDashboardAgent("api", "🦊", "/src/api", status: .input, title: "Awaiting API key"),
        previewDashboardAgent("docs", "📚", "/src/docs", status: .running, title: "Updating docs", gitStats: .init(insertions: 23, deletions: 5, files: 2)),
        previewDashboardAgent("tests", "🧪", "/src/tests", status: .idle, gitStats: .init(insertions: 8, deletions: 3, files: 1)),
    ]

    m.agents = agents1 + agents2

    let ws1 = Workspace(name: "Skwad", colorHex: WorkspaceColor.blue.rawValue, agentIds: agents1.map { $0.id })
    let ws2 = Workspace(name: "Backend", colorHex: WorkspaceColor.purple.rawValue, agentIds: agents2.map { $0.id })
    m.workspaces = [ws1, ws2]
    m.currentWorkspaceId = ws1.id
    m.showGlobalDashboard = true
    return m
}

@MainActor private func previewWorkspaceDashboardManager() -> (AgentManager, UUID) {
    let m = AgentManager()
    let agents = [
        previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Implementing dashboard views", gitStats: .init(insertions: 156, deletions: 12, files: 5)),
        previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),
        previewDashboardAgent("api", "🦊", "/Users/nbonamy/src/api", status: .input, title: "Awaiting API key"),
    ]
    m.agents = agents
    let workspace = Workspace(name: "My Project", colorHex: WorkspaceColor.purple.rawValue, agentIds: agents.map { $0.id })
    m.workspaces = [workspace]
    m.currentWorkspaceId = workspace.id
    return (m, workspace.id)
}

#Preview("Global Dashboard") {
    DashboardView(forkPrefill: .constant(nil), workspaceId: nil)
        .environment(previewGlobalDashboardManager())
        .frame(width: 900, height: 600)
}

#Preview("Workspace Dashboard") {
    let (manager, wsId) = previewWorkspaceDashboardManager()
    DashboardView(forkPrefill: .constant(nil), workspaceId: wsId)
        .environment(manager)
        .frame(width: 900, height: 600)
}
