import SwiftUI

struct BenchManagementSheet: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Bench")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            if settings.benchAgents.isEmpty {
                VStack(spacing: 8) {
                    Text("No agents on bench")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text("Right-click an agent and select \"Save to Bench\" to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settings.benchAgents) { benchAgent in
                        BenchManagementRow(benchAgent: benchAgent, onRename: { newName in
                            settings.updateBenchAgent(id: benchAgent.id, name: newName)
                        }, onDelete: {
                            settings.removeFromBench(benchAgent)
                        })
                    }
                    .onMove { source, destination in
                        settings.moveBenchAgent(from: source, to: destination)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 420, height: 480)
    }
}

struct BenchManagementRow: View {
    let benchAgent: BenchAgent
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var editedName: String = ""
    @State private var isEditing = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(avatar: benchAgent.avatar, size: 32, font: .title2)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Name", text: $editedName, onCommit: {
                        commitRename()
                    })
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
                    .focused($nameFieldFocused)
                    .onExitCommand {
                        isEditing = false
                    }
                } else {
                    Text(benchAgent.name)
                        .font(.body.weight(.medium))
                        .onTapGesture(count: 2) {
                            editedName = benchAgent.name
                            isEditing = true
                            nameFieldFocused = true
                        }
                }

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

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from bench")
        }
        .padding(.vertical, 2)
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
        isEditing = false
    }
}
