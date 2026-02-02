import SwiftUI
import AppKit

// NSView that enables window dragging and fires an onTap callback on single click
struct WindowDragView: NSViewRepresentable {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        view.wantsLayer = true
        view.onTap = context.coordinator.onTap
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowDragNSView)?.onTap = context.coordinator.onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    class Coordinator {
        let onTap: (() -> Void)?
        init(onTap: (() -> Void)?) { self.onTap = onTap }
    }
}

class WindowDragNSView: NSView {
    var onTap: (() -> Void)?
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onTap?()
        if event.clickCount == 2 {
            window?.zoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

struct AgentTerminalView: View {
    @EnvironmentObject var agentManager: AgentManager
    @ObservedObject private var settings = AppSettings.shared
    let agent: Agent
    let paneIndex: Int
    @Binding var sidebarVisible: Bool
    let onGitStatsTap: () -> Void
    let onPaneTap: () -> Void

    @State private var isWindowResizing = false
    @State private var controller: TerminalSessionController?

    private var isActive: Bool {
        agentManager.activeAgentId == agent.id
    }

    var body: some View {
        VStack(spacing: 0) {
            if sidebarVisible {
                AgentFullHeader(agent: agent, isFocused: isActive, onGitStatsTap: onGitStatsTap, onPaneTap: onPaneTap)
            } else {
              AgentCompactHeader(agent: agent, paneIndex: paneIndex, onShowSidebar: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        sidebarVisible = true
                    }
                })
            }

            // Terminal view - controller must exist
            if let controller = controller {
                if settings.terminalEngine == "ghostty" {
                    GhosttyTerminalWrapperView(
                        controller: controller,
                        isActive: isActive,
                        onTerminalCreated: { terminal in
                            agentManager.registerTerminal(terminal, for: agent.id)
                        },
                        onPaneTap: onPaneTap
                    )
                } else {
                    SwiftTermTerminalWrapperView(
                        controller: controller,
                        isActive: isActive,
                        onPaneTap: onPaneTap
                    )
                }
            }
        }
        .background(WindowResizeObserver(isResizing: $isWindowResizing))
        .onChange(of: isWindowResizing) { _, resizing in
            guard !resizing else { return }
            if settings.terminalEngine == "ghostty" {
                DispatchQueue.main.async {
                    agentManager.getTerminal(for: agent.id)?.forceRefresh()
                }
            }
        }
        .onAppear {
            // Create controller when view appears
            controller = agentManager.createController(for: agent)
        }
    }

}

// MARK: - Full Header (sidebar visible)

struct AgentFullHeader: View {
    let agent: Agent
    let isFocused: Bool
    let onGitStatsTap: () -> Void
    let onPaneTap: () -> Void

    @EnvironmentObject var agentManager: AgentManager
    @ObservedObject private var settings = AppSettings.shared

    private var isUnfocusedInSplit: Bool {
        agentManager.layoutMode != .single && !isFocused
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    leftVariant(showTitle: true, showFolder: true)
                    leftVariant(showTitle: false, showFolder: true)
                    leftVariant(showTitle: false, showFolder: false)
                }
                Spacer()
            }
            .background(WindowDragView(onTap: onPaneTap))

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(agent.status.color)
                        .frame(width: 10, height: 10)
                    Text(agent.status.rawValue)
                        .font(.body)
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }

                if let stats = agent.gitStats {
                    if stats.insertions == 0 && stats.deletions == 0 {
                        Text("Clean")
                            .foregroundColor(Theme.secondaryText)
                            .font(.body)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 8) {
                            Text("+\(stats.insertions)")
                                .foregroundColor(.green)
                                .font(.body.monospaced())
                                .lineLimit(1)
                            Text("-\(stats.deletions)")
                                .foregroundColor(.red)
                                .font(.body.monospaced())
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("Getting stats...")
                        .foregroundColor(Theme.secondaryText)
                        .font(.body)
                        .lineLimit(1)
                }
            }
            .opacity(isUnfocusedInSplit ? Theme.unfocusedHeaderOpacity : 1.0)
            .contentShape(Rectangle())
            .onTapGesture {
                onGitStatsTap()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(settings.sidebarBackgroundColor)
    }

    @ViewBuilder
    private func leftVariant(showTitle: Bool, showFolder: Bool) -> some View {
        HStack(spacing: 12) {
            AvatarView(avatar: agent.avatar, size: 36, font: .largeTitle)
                .opacity(isUnfocusedInSplit ? Theme.unfocusedHeaderOpacity : 1.0)

            Text(agent.name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .opacity(isUnfocusedInSplit ? Theme.unfocusedHeaderOpacity : 1.0)

            if showFolder {
                Text(shortenPath(agent.folder))
                    .font(.title3)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(isUnfocusedInSplit ? Theme.unfocusedHeaderOpacity : 1.0)
            }

            if showTitle, !agent.displayTitle.isEmpty {
                Text("●")
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
                Text(agent.displayTitle)
                    .font(.title3)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                .opacity(isUnfocusedInSplit ? Theme.unfocusedHeaderOpacity : 1.0)
            }
        }
    }
}

// MARK: - Compact Header (sidebar collapsed)

struct AgentCompactHeader: View {
    let agent: Agent
    let paneIndex: Int
    let onShowSidebar: () -> Void

    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 10) {
          
          if (paneIndex == 0) {
            Button {
              onShowSidebar()
            } label: {
              Image(systemName: "sidebar.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.secondaryText)
            }
            .buttonStyle(.plain)
            .help("Show sidebar")
          }

            AvatarView(avatar: agent.avatar, size: 16, font: .title3)

            Text(agent.name)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)

            Text("•")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.secondaryText)

            Text(shortenPath(agent.folder))
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            if !agent.displayTitle.isEmpty {
                Text("•")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.secondaryText)

                Text(agent.displayTitle)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())

            HStack(spacing: 6) {
                Circle()
                    .fill(agent.status.color)
                    .frame(width: 8, height: 8)
                Text(agent.status.rawValue)
                    .font(.callout)
                    .foregroundColor(Theme.secondaryText)
            }
        }
        .padding(.leading, paneIndex == 0 ? 82 : 16)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(settings.sidebarBackgroundColor)
    }
}

private func shortenPath(_ path: String) -> String {
    if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
        return "~" + path.dropFirst(home.count)
    }
    return path
}


// MARK: - Preview

private func previewAgent(_ name: String, _ avatar: String, _ folder: String, status: AgentStatus = .idle, title: String = "", stats: GitLineStats? = nil) -> Agent {
    var agent = Agent(name: name, avatar: avatar, folder: folder)
    agent.status = status
    agent.terminalTitle = title
    agent.gitStats = stats
    return agent
}

@MainActor private func previewAgentManager() -> AgentManager {
    let skwad = previewAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Editing ContentView.swift", stats: .init(insertions: 42, deletions: 7, files: 3))
    let witsy = previewAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .idle, stats: .init(insertions: 0, deletions: 0, files: 0))
    let broken = previewAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error)
    let m = AgentManager()
    m.agents = [skwad, witsy, broken]
    m.activeAgentIds = [skwad.id, witsy.id]
    m.layoutMode = .splitVertical
    return m
}

#Preview("Full Header") {
    let manager = previewAgentManager()
    VStack(spacing: 0) {
        AgentFullHeader(agent: manager.agents[0], isFocused: true, onGitStatsTap: {}, onPaneTap: {})
        Divider()
        AgentFullHeader(agent: manager.agents[1], isFocused: false, onGitStatsTap: {}, onPaneTap: {})
        Divider()
        AgentFullHeader(agent: manager.agents[2], isFocused: false, onGitStatsTap: {}, onPaneTap: {})
    }
    .frame(width: 600)
    .environmentObject(manager)
}

#Preview("Compact Header") {
    VStack(spacing: 0) {
      AgentCompactHeader(agent: previewAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Editing ContentView.swift"), paneIndex: 0, onShowSidebar: {})
        Divider()
      AgentCompactHeader(agent: previewAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .idle), paneIndex: 1, onShowSidebar: {})
        Divider()
      AgentCompactHeader(agent: previewAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .error), paneIndex: 1, onShowSidebar: {})
    }
    .frame(width: 600)
}

// MARK: - Ghostty Terminal Wrapper
// Ghostty handles its own padding via window-padding-x/y config

struct GhosttyTerminalWrapperView: View {
    let controller: TerminalSessionController
    let isActive: Bool
    let onTerminalCreated: (GhosttyTerminalView) -> Void
    let onPaneTap: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            GhosttyHostView(
                controller: controller,
                size: proxy.size,
                isActive: isActive,
                onTerminalCreated: onTerminalCreated,
                onPaneTap: onPaneTap
            )
        }
    }
}

// MARK: - SwiftTerm Terminal Wrapper
// Uses SwiftUI padding + background color from settings

struct SwiftTermTerminalWrapperView: View {
    @ObservedObject private var settings = AppSettings.shared
    let controller: TerminalSessionController
    let isActive: Bool
    let onPaneTap: (() -> Void)?

    var body: some View {
        TerminalHostView(
            controller: controller,
            isActive: isActive,
            onPaneTap: onPaneTap
        )
        .padding(12)
        .background(settings.terminalBackgroundColor)
    }
}
