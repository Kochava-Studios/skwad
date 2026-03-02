import SwiftUI

struct BenchPopoverView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var forkPrefill: AgentPrefill?
    let dismiss: () -> Void

    @State private var showManagementSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bench")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if settings.benchAgents.isEmpty {
                VStack(spacing: 8) {
                    Text("No agents on bench")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Right-click an agent and select\n\"Save to Bench\" to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(settings.benchAgents) { benchAgent in
                            BenchAgentRow(benchAgent: benchAgent)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if NSEvent.modifierFlags.contains(.option) {
                                        // Option+click: open AgentSheet pre-filled
                                        forkPrefill = AgentPrefill(
                                            name: benchAgent.name,
                                            avatar: benchAgent.avatar,
                                            folder: benchAgent.folder,
                                            agentType: benchAgent.agentType
                                        )
                                        dismiss()
                                    } else {
                                        // Click: immediate deploy
                                        agentManager.addAgent(
                                            folder: benchAgent.folder,
                                            name: benchAgent.name,
                                            avatar: benchAgent.avatar,
                                            agentType: benchAgent.agentType,
                                            shellCommand: benchAgent.shellCommand
                                        )
                                        dismiss()
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 340)
            }

            Divider()

            Button {
                showManagementSheet = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Manage Bench...")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
        .sheet(isPresented: $showManagementSheet) {
            BenchManagementSheet()
        }
    }
}

struct BenchAgentRow: View {
    let benchAgent: BenchAgent

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(avatar: benchAgent.avatar, size: 28, font: .title2)

            VStack(alignment: .leading, spacing: 1) {
                Text(benchAgent.name)
                    .font(.body)
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(URL(fileURLWithPath: benchAgent.folder).lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if benchAgent.agentType != "claude" {
                        Text("(\(benchAgent.agentType))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
