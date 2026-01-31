import SwiftUI
import AppKit

// NSView that enables window dragging
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            // Double-click to zoom/maximize
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
    let onGitStatsTap: () -> Void

    @State private var isWindowResizing = false
    @State private var controller: TerminalSessionController?

    private var isActive: Bool {
        agentManager.selectedAgentId == agent.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - same color as sidebar
            HStack(spacing: 12) {
                // Left side + spacer - draggable
                HStack(spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        headerLeftVariant(showTitle: true, showFolder: true)
                        headerLeftVariant(showTitle: false, showFolder: true)
                        headerLeftVariant(showTitle: false, showFolder: false)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                
                // Right side - clickable (status + git stats)
                headerRight
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(settings.sidebarBackgroundColor)

            // Terminal view - controller must exist
            if let controller = controller {
                if settings.terminalEngine == "ghostty" {
                    GhosttyTerminalWrapperView(
                        controller: controller,
                        isActive: isActive,
                        onTerminalCreated: { terminal in
                            agentManager.registerTerminal(terminal, for: agent.id)
                        }
                    )
                } else {
                    SwiftTermTerminalWrapperView(
                        controller: controller,
                        isActive: isActive
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

    private func shortenPath(_ path: String) -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    @ViewBuilder
    private func headerLeftVariant(showTitle: Bool, showFolder: Bool) -> some View {
        HStack(spacing: 12) {
            AvatarView(avatar: agent.avatar, size: 36, font: .largeTitle)

            Text(agent.name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)

            if showFolder {
                Text(shortenPath(agent.folder))
                    .font(.title3)
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
            }
        }
    }
    
    @ViewBuilder
    private var headerRight: some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            onGitStatsTap()
        }
    }
}


// MARK: - Ghostty Terminal Wrapper
// Ghostty handles its own padding via window-padding-x/y config

struct GhosttyTerminalWrapperView: View {
    let controller: TerminalSessionController
    let isActive: Bool
    let onTerminalCreated: (GhosttyTerminalView) -> Void

    var body: some View {
        GeometryReader { proxy in
            GhosttyHostView(
                controller: controller,
                size: proxy.size,
                isActive: isActive,
                onTerminalCreated: onTerminalCreated
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

    var body: some View {
        TerminalHostView(
            controller: controller,
            isActive: isActive
        )
        .padding(12)
        .background(settings.terminalBackgroundColor)
    }
}
