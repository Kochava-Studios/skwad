import SwiftUI

struct AgentTypePicker: View {
    let label: String
    @Binding var selection: String
    var iconSize: CGFloat = 18

    private var selectedAgent: AgentCommandOption? {
        availableAgents.first { $0.id == selection }
    }

    var body: some View {
        LabeledContent(label) {
            Menu {
                ForEach(availableAgents) { agent in
                    if agent.isDividerBefore {
                        Divider()
                    }
                    Button {
                        selection = agent.id
                    } label: {
                        AgentTypePickerContent(agent: agent, iconSize: iconSize)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let agent = selectedAgent {
                        AgentTypePickerContent(agent: agent, iconSize: iconSize)
                    } else {
                        Text("Select agent")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .font(.body)
        }
    }
}

#Preview {
    @Previewable @State var selection = "claude"
    Form {
        AgentTypePicker(label: "Coding Agent", selection: $selection)
    }
    .formStyle(.grouped)
    .frame(width: 400)
}