import SwiftUI

enum DashboardMetrics {
    static let gridColumns = [GridItem(.adaptive(minimum: 300, maximum: 300), spacing: 16, alignment: .leading)]
    static let gridSpacing: CGFloat = 16

    static func idleDuration(since date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 {
            return "< 1 minute ago"
        }
        let minutes = seconds / 60
        return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    }
}

struct AgentCardView: View {
    let agent: Agent
    let onTap: () -> Void
    let onSend: (String) -> Void
    let onSendAndSwitch: (String) -> Void
    let now: Date

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: avatar + name + status
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 10)

            // Info section: title, folder, git stats
            infoSection
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            // Quick prompt
            QuickPromptField(
                agent: agent,
                onSend: onSend,
                onSendAndSwitch: onSendAndSwitch
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(minHeight: 160)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            AvatarView(avatar: agent.avatar, size: 36, font: .title)

            VStack(alignment: .leading) {
                Text(agent.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)

                // Working folder + branch
                HStack(spacing: 4) {
                    if agent.workingFolder != agent.folder {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 12))
                    }
                    Text(URL(fileURLWithPath: agent.workingFolder).lastPathComponent)
                        .lineLimit(1)
                }
                .font(.body)
                .foregroundColor(Theme.secondaryText)
            }

            Spacer()

            if !agent.isShell {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(agent.state.rawValue)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(agent.state.color)

                    if agent.state == .idle {
                        Text(DashboardMetrics.idleDuration(since: agent.lastStatusChange, now: now))
                            .font(.caption)
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Agent status (from set-status MCP tool) or terminal title fallback
            if !agent.statusText.isEmpty {
                Text(agent.statusText)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(2)
            } else if !agent.displayTitle.isEmpty {
                Text(agent.displayTitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
            }

            // Git stats
            if let stats = agent.gitStats {
                GitStatsView(stats: stats)
            }
        }
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.primary.opacity(0.04))
    }

    private var cardBorder: Color {
        if agent.state == .input {
            return agent.state.color.opacity(0.6)
        }
        return Color.primary.opacity(isHovered ? 0.15 : 0.08)
    }

}

// MARK: - Preview Helpers

func previewDashboardAgent(_ name: String, _ avatar: String, _ folder: String, status: AgentState = .idle, title: String = "", gitStats: GitLineStats? = nil) -> Agent {
    var agent = Agent(name: name, avatar: avatar, folder: folder)
    agent.state = status
    agent.terminalTitle = title
    agent.gitStats = gitStats
    return agent
}

#Preview("Agent Card - Idle") {
    AgentCardView(
        agent: previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),

        onTap: {},
        onSend: { _ in },
        onSendAndSwitch: { _ in },
        now: Date()
    )
    .frame(width: 280, height: 220)
    .padding()
}

#Preview("Agent Card - Working") {
    AgentCardView(
        agent: previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .running, title: "Editing ContentView.swift", gitStats: .init(insertions: 42, deletions: 7, files: 3)),

        onTap: {},
        onSend: { _ in },
        onSendAndSwitch: { _ in },
        now: Date()
    )
    .frame(width: 280, height: 220)
    .padding()
}

#Preview("Agent Card - Needs Input") {
    AgentCardView(
        agent: previewDashboardAgent("broken", "🦊", "/Users/nbonamy/src/broken", status: .input, title: "Waiting for confirmation"),

        onTap: {},
        onSend: { _ in },
        onSendAndSwitch: { _ in },
        now: Date()
    )
    .frame(width: 280, height: 240)
    .padding()
}

#Preview("Agent Cards Grid") {
    let agents = [
        previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Implementing dashboard views", gitStats: .init(insertions: 156, deletions: 12, files: 5)),
        previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),
        previewDashboardAgent("api", "🦊", "/Users/nbonamy/src/api", status: .input, title: "Awaiting API key"),
        previewDashboardAgent("docs", "📚", "/Users/nbonamy/src/docs", status: .running, title: "Updating README.md", gitStats: .init(insertions: 23, deletions: 5, files: 2)),
    ]

    LazyVGrid(columns: DashboardMetrics.gridColumns, spacing: DashboardMetrics.gridSpacing) {
        ForEach(agents) { agent in
            AgentCardView(
                agent: agent,
        
                onTap: {},
                onSend: { _ in },
                onSendAndSwitch: { _ in },
                now: Date()
            )
            .frame(height: 220)
        }
    }
    .padding(24)
    .frame(width: 700)
}
