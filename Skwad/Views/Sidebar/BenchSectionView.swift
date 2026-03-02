import SwiftUI

struct BenchDropdownView: View {
    @ObservedObject private var settings = AppSettings.shared
    let onNewAgent: () -> Void
    let onDeploy: (BenchAgent) -> Void

    @State private var hoveredAgentId: UUID?
    @State private var agentToDelete: BenchAgent?

    var body: some View {
        VStack(spacing: 0) {

            // Create new agent
            Button {
                onNewAgent()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24)
                    Text("Create New Agent")
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 4)

            HStack {
                Text("BENCH")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            if settings.benchAgents.isEmpty {
                Text("Right-click an agent → Save to Bench")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(settings.benchAgents) { benchAgent in
                            HStack(spacing: 8) {
                                AvatarView(avatar: benchAgent.avatar, size: 24, font: .title3)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(benchAgent.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)

                                    Text(URL(fileURLWithPath: benchAgent.folder).lastPathComponent)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if hoveredAgentId == benchAgent.id {
                                    Button {
                                        agentToDelete = benchAgent
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from bench")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(hoveredAgentId == benchAgent.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                            .onHover { isHovered in
                                hoveredAgentId = isHovered ? benchAgent.id : nil
                            }
                            .onTapGesture {
                                onDeploy(benchAgent)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 260)
        .alert("Remove from Bench", isPresented: Binding(
            get: { agentToDelete != nil },
            set: { if !$0 { agentToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { agentToDelete = nil }
            Button("Remove", role: .destructive) {
                if let agent = agentToDelete {
                    withAnimation {
                        settings.removeFromBench(agent)
                    }
                    agentToDelete = nil
                }
            }
        } message: {
            if let agent = agentToDelete {
                Text("Remove \"\(agent.name)\" from your bench?")
            }
        }
    }
}
