import SwiftUI

/// A standalone view for a workspace detached to its own window.
/// Shows sidebar + terminal area for a single workspace (no workspace bar).
struct DetachedWorkspaceView: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var sidebarWidth: CGFloat = 250
    @State private var sidebarVisible = true
    @State private var showGitPanel = false
    @State private var showFileFinder = false
    @State private var showNewAgentSheet = false
    @State private var forkPrefill: AgentPrefill?
    @State private var artifactExpanded = false
    @State private var lastPaneRects: [UUID: CGRect] = [:]
    @State private var showCloseDialog = false

    let workspaceId: UUID

    private var workspace: Workspace? {
        agentManager.workspaces.first { $0.id == workspaceId }
    }

    private var workspaceAgents: [Agent] {
        guard let workspace else { return [] }
        return workspace.agentIds.compactMap { id in agentManager.agents.first { $0.id == id } }
    }

    /// Non-companion agents for sidebar display
    private var sidebarAgents: [Agent] {
        workspaceAgents.filter { !$0.isCompanion }
    }

    private var activeAgent: Agent? {
        guard let workspace else { return nil }
        let activeIds = workspace.activeAgentIds
        let focusedIndex = workspace.focusedPaneIndex
        guard focusedIndex < activeIds.count else {
            guard let firstId = activeIds.first else { return nil }
            return agentManager.agents.first { $0.id == firstId }
        }
        let agentId = activeIds[focusedIndex]
        return agentManager.agents.first { $0.id == agentId }
    }

    private var activeAgentIds: [UUID] {
        workspace?.activeAgentIds ?? []
    }

    private var layoutMode: LayoutMode {
        workspace?.layoutMode ?? .single
    }

    private var canShowGitPanel: Bool {
        guard let agent = activeAgent else { return false }
        return GitWorktreeManager.shared.isGitRepo(agent.folder)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            terminalArea
            gitPanel
            artifactPanel
        }
        .background(settings.sidebarBackgroundColor)
        .frame(minWidth: 700, minHeight: 500)
        .ignoresSafeArea()
        .background(WindowTitleSetter(title: workspace?.name ?? "Workspace"))
        .overlay {
            if showFileFinder, let agent = activeAgent {
                FileFinderView(
                    folder: agent.workingFolder,
                    onDismiss: { showFileFinder = false },
                    onSelect: { path in
                        Clipboard.copy(path)
                        agentManager.sendText(path, for: agent.id)
                        showFileFinder = false
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: showGitPanel) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if let agent = activeAgent {
                    agentManager.notifyTerminalResize(for: agent.id)
                }
            }
        }
        .onChange(of: workspace?.isDetachedFromMain) { _, isDetached in
            if isDetached != true {
                dismiss()
            }
        }
        .sheet(isPresented: $showNewAgentSheet) {
            AgentSheet()
                .environment(agentManager)
        }
        .sheet(item: $forkPrefill) { prefill in
            AgentSheet(prefill: prefill)
                .environment(agentManager)
        }
        .background(
            WindowCloseInterceptor(onCloseAttempt: {
                showCloseDialog = true
            })
        )
        .alert("Close Workspace Window", isPresented: $showCloseDialog) {
            Button("Re-attach") {
                if let ws = workspace {
                    agentManager.reattachWorkspace(ws)
                }
            }
            Button("Close Workspace", role: .destructive) {
                if let ws = workspace {
                    agentManager.removeWorkspace(ws)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let ws = workspace {
                Text("What would you like to do with \"\(ws.name)\"?")
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        if !workspaceAgents.isEmpty && sidebarVisible {
            VStack(spacing: 0) {
                workspaceHeader

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(sidebarAgents) { agent in
                            AgentRowView(agent: agent, isSelected: agentManager.isAgentActive(agent.id), isCompact: false)
                                .onTapGesture {
                                    agentManager.selectAgent(agent.id)
                                }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }

                Spacer(minLength: 0)
            }
            .frame(width: sidebarWidth)

            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newWidth = sidebarWidth + value.translation.width
                            sidebarWidth = min(max(newWidth, ContentView.minSidebarWidth), ContentView.maxSidebarWidth)
                        }
                )
        }
    }

    private var workspaceHeader: some View {
        WindowDragView {
            // no-op tap
        }
        .frame(height: 0)
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                Circle()
                    .fill(workspace?.color ?? .blue)
                    .frame(width: 10, height: 10)

                Text(workspace?.name ?? "Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Button {
                    if let ws = workspace {
                        agentManager.reattachWorkspace(ws)
                    }
                } label: {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Re-attach to main window")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 40)
        .background(settings.sidebarBackgroundColor.withAddedContrast(by: 0.03))
    }

    // MARK: - Terminal Area

    private var terminalArea: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(workspaceAgents) { agent in
                    terminalView(for: agent, in: geo)
                }

                if workspaceAgents.isEmpty {
                    emptyState
                }
            }
        }
        .opacity(artifactExpanded ? 0 : 1)
        .frame(width: artifactExpanded ? 0 : nil)
        .allowsHitTesting(!artifactExpanded)
        .clipped()
    }

    private func terminalView(for agent: Agent, in geo: GeometryProxy) -> some View {
        let visible = activeAgentIds.contains(agent.id)
        let rect = visible ? paneRect(for: agent.id, in: geo.size) : (lastPaneRects[agent.id] ?? CGRect(origin: .zero, size: geo.size))
        let paneIdx = activeAgentIds.firstIndex(of: agent.id) ?? 0

        return AgentTerminalView(
            agent: agent,
            paneIndex: paneIdx,
            suppressFocus: showFileFinder,
            sidebarVisible: $sidebarVisible,
            forkPrefill: $forkPrefill,
            onGitStatsTap: {
                if GitWorktreeManager.shared.isGitRepo(agent.folder) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showGitPanel.toggle()
                    }
                }
            },
            onPaneTap: {
                if let pane = activeAgentIds.firstIndex(of: agent.id) {
                    agentManager.focusPane(pane)
                }
            }
        )
        .id("\(agent.id)-\(agent.restartToken)")
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .onAppear {
            if lastPaneRects[agent.id] == nil {
                lastPaneRects[agent.id] = CGRect(origin: .zero, size: geo.size)
            }
        }
        .onChange(of: visible) { _, isVisible in
            if isVisible {
                lastPaneRects[agent.id] = paneRect(for: agent.id, in: geo.size)
            }
        }
    }

    private func paneRect(for agentId: UUID, in size: CGSize) -> CGRect {
        if layoutMode == .single {
            return CGRect(origin: .zero, size: size)
        }
        let pane = activeAgentIds.firstIndex(of: agentId) ?? 0
        return ContentView.computePaneRect(
            pane: pane,
            layoutMode: layoutMode,
            splitRatio: workspace?.splitRatio ?? 0.5,
            splitRatioSecondary: workspace?.effectiveSplitRatioSecondary ?? 0.5,
            in: size
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text(workspace?.name ?? "Workspace")
                .font(.title)
                .foregroundColor(.primary)

            Text("No agents in this workspace")
                .font(.body)
                .foregroundColor(.secondary)

            Button("New Agent...") {
                showNewAgentSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.effectiveBackgroundColor)
    }

    // MARK: - Git Panel

    @ViewBuilder
    private var gitPanel: some View {
        if showGitPanel, let agent = activeAgent {
            GitPanelView(folder: agent.folder) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showGitPanel = false
                }
            }
            .transition(.move(edge: .trailing))
        }
    }

    // MARK: - Artifact Panel

    @ViewBuilder
    private var artifactPanel: some View {
        if let agent = activeAgent, agent.markdownFilePath != nil || agent.mermaidSource != nil {
            ArtifactPanelView(
                agent: agent,
                isExpanded: $artifactExpanded,
                onCloseMarkdown: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        agentManager.closeMarkdownPanel(for: agent.id)
                        if agent.mermaidSource == nil {
                            artifactExpanded = false
                        }
                    }
                },
                onCloseMermaid: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        agentManager.closeMermaidPanel(for: agent.id)
                        if agent.markdownFilePath == nil {
                            artifactExpanded = false
                        }
                    }
                },
                onMarkdownApprove: { text in
                    agentManager.injectText(text, for: agent.id)
                },
                onMarkdownComment: { text in
                    agentManager.sendText(text, for: agent.id)
                },
                onMarkdownSubmitReview: {
                    agentManager.submitReturn(for: agent.id)
                }
            )
            .transition(.move(edge: .trailing))
        }
    }
}

// MARK: - Window Title Setter

/// Sets the NSWindow title for use in Mission Control and Window menu
private struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.title = title
    }
}

// MARK: - Window Close Interceptor

/// NSViewRepresentable that intercepts the window close button to show a custom dialog.
private struct WindowCloseInterceptor: NSViewRepresentable {
    let onCloseAttempt: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Defer window access to next runloop (view isn't in window yet)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.window = window
            // Replace close button target
            if let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.target = context.coordinator
                closeButton.action = #selector(Coordinator.closeButtonClicked)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onCloseAttempt = onCloseAttempt
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCloseAttempt: onCloseAttempt)
    }

    class Coordinator: NSObject {
        var onCloseAttempt: () -> Void
        weak var window: NSWindow?

        init(onCloseAttempt: @escaping () -> Void) {
            self.onCloseAttempt = onCloseAttempt
        }

        @objc func closeButtonClicked() {
            onCloseAttempt()
        }
    }
}
