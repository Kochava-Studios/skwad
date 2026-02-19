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

enum InputDetectionAction: String, CaseIterable {
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

struct AISettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Text("When an agent goes idle, analyze its last message with an LLM to detect if user input is needed.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("About")
            }

            Section {
                Toggle("Enable input detection", isOn: $settings.aiInputDetectionEnabled)
            } header: {
                Text("Input Detection")
            }

            Section {
                Picker("Provider", selection: $settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.rawValue) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .onChange(of: settings.aiProvider) { _, _ in
                    // Clear custom model when switching providers so default kicks in
                    settings.aiModel = ""
                }

                LabeledContent("API Key") {
                    SecureField("", text: $settings.aiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Model") {
                    TextField("", text: $settings.aiModel, prompt: Text(AppSettings.defaultModel(for: settings.aiProvider)))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            } header: {
                Text("AI Provider")
            } footer: {
                Text("Using model: \(settings.effectiveAiModel)")
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("When input is detected", selection: $settings.aiInputDetectionAction) {
                    ForEach(InputDetectionAction.allCases, id: \.rawValue) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
            } header: {
                Text("Action")
            } footer: {
                let action = InputDetectionAction(rawValue: settings.aiInputDetectionAction) ?? .mark
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
    AISettingsView()
}
