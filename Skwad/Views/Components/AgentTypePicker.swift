import SwiftUI

struct AgentTypePicker: View {
    let label: String
    @Binding var selection: String
    var iconSize: CGFloat = 18

    var body: some View {
        LabeledContent(label) {
            Picker("", selection: $selection) {
                ForEach(availableAgents) { agent in
                    AgentTypePickerContent(agent: agent, iconSize: iconSize)
                        .tag(agent.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.body)
        }
    }
}