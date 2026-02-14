import SwiftUI

struct ConversationHistoryView: View {
    @Environment(AgentManager.self) var agentManager
    let agent: Agent
    let historyService = ConversationHistoryService.shared

    @AppStorage("conversationHistoryExpanded") private var isExpanded = false
    @State private var hoveredSessionId: String?
    @State private var sessionToDelete: ConversationHistoryService.SessionSummary?

    var body: some View {
        VStack(spacing: 0) {

          Divider()

            // Section header
            HStack {
              Text("Conversations".uppercased())
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(height: 32)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            if isExpanded {
                conversationList
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isExpanded)
        .task(id: agent.id) {
            await historyService.refresh(for: agent.folder, agentType: agent.agentType)
        }
        .onChange(of: agent.status) { oldValue, newValue in
            if newValue == .idle {
                Task {
                    await historyService.refresh(for: agent.folder, agentType: agent.agentType)
                }
            }
        }
        .alert("Delete Conversation", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    Task {
                        await historyService.deleteSession(id: session.id, folder: agent.folder, agentType: agent.agentType)
                    }
                    sessionToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete this conversation.")
        }
    }

    @ViewBuilder
    private var conversationList: some View {
        let sessions = historyService.sessions(for: agent.folder, agentType: agent.agentType)

        if historyService.isLoading && sessions.isEmpty {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else if sessions.isEmpty {
            Text("No conversations yet")
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sessions) { session in
                        let isCurrent = session.id == agent.sessionId
                        SessionRowView(
                            session: session,
                            isCurrent: isCurrent,
                            isHovered: hoveredSessionId == session.id,
                            onResume: {
                                agentManager.resumeSession(agent, sessionId: session.id)
                            }
                        )
                        .onHover { isHovered in
                            hoveredSessionId = isHovered ? session.id : nil
                        }
                        .contextMenu {
                            if !isCurrent {
                                Button("Resume Session") {
                                    agentManager.resumeSession(agent, sessionId: session.id)
                                }
                            }
                            Button("Copy Session ID") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(session.id, forType: .string)
                            }
                            Divider()
                            Button("Delete Conversation", role: .destructive) {
                                sessionToDelete = session
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: ConversationHistoryService.SessionSummary
    var isCurrent: Bool = false
    let isHovered: Bool
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty
                     ? (isCurrent ? "Current conversation" : "Untitled conversation")
                     : session.title)
                    .font(.system(size: 13))
                    .foregroundColor(session.title.isEmpty ? Theme.secondaryText : Theme.primaryText)
                    .italic(session.title.isEmpty)
                    .lineLimit(1)

                Text(relativeDate(session.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()

            if isCurrent {
                Circle()
                    .fill(Theme.secondaryText.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .frame(width: 24, height: 24)
            } else if isHovered {
                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Resume session")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.selectionBackground.opacity(0.5) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Previews

private func previewSession(_ title: String, minutesAgo: Int, messages: Int = 12) -> ConversationHistoryService.SessionSummary {
    ConversationHistoryService.SessionSummary(
        id: UUID().uuidString,
        title: title,
        timestamp: Date().addingTimeInterval(-Double(minutesAgo) * 60),
        messageCount: messages
    )
}

#Preview("Session Rows") {
    let current = previewSession("Implement conversation history panel in sidebar", minutesAgo: 2)
    VStack(spacing: 2) {
        SessionRowView(session: current, isHovered: false, onResume: {})
        SessionRowView(session: previewSession("Fix authentication bug in login flow", minutesAgo: 45), isHovered: false, onResume: {})
        SessionRowView(session: previewSession("Add dark mode support to settings", minutesAgo: 120, messages: 34), isHovered: true, onResume: {})
        SessionRowView(session: previewSession("Refactor git operations to use async/await patterns", minutesAgo: 1440), isHovered: false, onResume: {})
    }
    .padding(8)
    .frame(width: 250)
}

#Preview("Conversation History") {
    let agent = Agent(name: "skwad", avatar: "🐱", folder: "/Users/nbonamy/src/skwad")
    let manager = AgentManager()
    ConversationHistoryView(agent: agent)
        .environment(manager)
        .frame(width: 250, height: 300)
}
