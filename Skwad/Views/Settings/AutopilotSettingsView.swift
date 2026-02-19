import SwiftUI

enum AIProvider: String, CaseIterable {
    case openai = "openai"
    case anthropic = "anthropic"
    case google = "google"

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        }
    }
}

enum AutopilotAction: String, CaseIterable {
    case mark = "mark"
    case ask = "ask"
    case `continue` = "continue"

    var displayName: String {
        switch self {
        case .mark: return "Mark conversation"
        case .ask: return "Ask me"
        case .continue: return "Auto-continue"
        }
    }

    var description: String {
        switch self {
        case .mark: return "Set the agent status to indicate input is needed and send a notification."
        case .ask: return "Show a dialog letting you switch to the agent, dismiss, or auto-continue."
        case .continue: return "Automatically send \"yes, continue\" to the agent."
        }
    }
}

struct AutopilotSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable autopilot", isOn: $settings.autopilotEnabled)
            } header: {
                Text("Autopilot")
            } footer: {
                Text("Automatically detect when agents need input and take action — no need to babysit your agents.")
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("Provider", selection: $settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                LabeledContent("API Key") {
                    SecureField("", text: $settings.aiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Model") {
                    Text(AppSettings.aiModel(for: settings.aiProvider))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("AI Provider")
            }

            Section {
                Picker("When input is detected", selection: $settings.autopilotAction) {
                    ForEach(AutopilotAction.allCases, id: \.rawValue) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
            } header: {
                Text("Action")
            } footer: {
                let action = AutopilotAction(rawValue: settings.autopilotAction) ?? .mark
                Text(action.description)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .padding()
    }
}

#Preview {
    AutopilotSettingsView()
}
