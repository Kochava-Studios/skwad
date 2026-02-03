import SwiftUI

struct WorkspaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AgentManager.self) var agentManager

    let workspace: Workspace?

    @State private var name: String = ""
    @State private var selectedColor: WorkspaceColor = .blue

    init(workspace: Workspace? = nil) {
        self.workspace = workspace
        if let workspace = workspace {
            _name = State(initialValue: workspace.name)
            _selectedColor = State(initialValue: WorkspaceColor.allCases.first { $0.rawValue == workspace.colorHex } ?? .blue)
        }
    }

    var isEditing: Bool { workspace != nil }

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text(isEditing ? "Edit Workspace" : "New Workspace")
                .font(.headline)

            // Preview
            ZStack {
                Circle()
                    .fill(selectedColor.color)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(previewInitials)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .padding(.vertical, 8)

            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Workspace name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                    ForEach(WorkspaceColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedColor == color ? Color.white : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .overlay(
                                selectedColor == color ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                    : nil
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button(isEditing ? "Save" : "Create") {
                    save()
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320, height: 440)
    }

    private var previewInitials: String {
        Workspace.computeInitials(from: name)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let workspace = workspace {
            agentManager.updateWorkspace(id: workspace.id, name: trimmedName, colorHex: selectedColor.rawValue)
        } else {
            _ = agentManager.addWorkspace(name: trimmedName, color: selectedColor)
        }
    }
}

#Preview("New Workspace") {
    WorkspaceSheet()
        .environment(AgentManager())
}

#Preview("Edit Workspace") {
    WorkspaceSheet(workspace: Workspace(name: "My Project", colorHex: WorkspaceColor.purple.rawValue))
        .environment(AgentManager())
}
