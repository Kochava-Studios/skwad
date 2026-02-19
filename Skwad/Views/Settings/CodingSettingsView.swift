import SwiftUI

struct AgentCommandOption: Identifiable {
  let id: String
  let name: String
  let icon: String?      // Asset image name
  let systemIcon: String? // SF Symbol fallback
  let needsLongStartup: Bool  // true for slow-starting agents like Gemini
  let isDividerBefore: Bool   // true to show divider before this option

  init(_ id: String, _ name: String, icon: String? = nil, systemIcon: String? = nil, needsLongStartup: Bool = false, isDividerBefore: Bool = false) {
    self.id = id
    self.name = name
    self.icon = icon
    self.systemIcon = systemIcon
    self.needsLongStartup = needsLongStartup
    self.isDividerBefore = isDividerBefore
  }
}

/// Shared list of available agent types
let availableAgents = [
  AgentCommandOption("claude", "Claude Code", icon: "claude"),
  AgentCommandOption("codex", "Codex", icon: "openai"),
  AgentCommandOption("opencode", "OpenCode", icon: "opencode"),
  AgentCommandOption("gemini", "Gemini CLI", icon: "gemini", needsLongStartup: true),
  AgentCommandOption("copilot", "GitHub Copilot", icon: "copilot"),
  AgentCommandOption("custom1", "Custom 1", systemIcon: "1.circle"),
  AgentCommandOption("custom2", "Custom 2", systemIcon: "2.circle"),
  AgentCommandOption("shell", "Shell", systemIcon: "terminal", isDividerBefore: true),
]

struct CodingSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  @State private var selectedAgentType: String = "claude"

  private var isCustomAgent: Bool {
    selectedAgentType == "custom1" || selectedAgentType == "custom2"
  }

  private var commandBinding: Binding<String> {
    Binding(
      get: { customCommand(for: selectedAgentType) },
      set: { setCustomCommand($0, for: selectedAgentType) }
    )
  }

  private func customCommand(for agentType: String) -> String {
    switch agentType {
    case "custom1": settings.customAgent1Command
    case "custom2": settings.customAgent2Command
    default: agentType
    }
  }

  private func setCustomCommand(_ value: String, for agentType: String) {
    switch agentType {
    case "custom1": settings.customAgent1Command = value
    case "custom2": settings.customAgent2Command = value
    default: break
    }
  }

  private var optionsBinding: Binding<String> {
    Binding(
      get: { settings.getOptions(for: selectedAgentType) },
      set: { settings.setOptions($0, for: selectedAgentType) }
    )
  }

  var body: some View {
    Form {
      Section {
        LabeledContent("Source folder") {
          HStack {
            Text(settings.sourceBaseFolder.isEmpty ? "Not configured" : settings.sourceBaseFolder)
              .foregroundColor(settings.sourceBaseFolder.isEmpty ? .secondary : .primary)
              .lineLimit(1)
              .truncationMode(.middle)

            Spacer()

            if !settings.sourceBaseFolder.isEmpty {
              Button {
                settings.sourceBaseFolder = ""
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.secondary)
              }
              .buttonStyle(.plain)
            }

            Button("Choose...") {
              selectSourceFolder()
            }
          }
        }
      } header: {
        Text("Source Folder")
      } footer: {
        Text("Base folder containing your git repositories (e.g. ~/src). Enables quick repo and worktree selection when creating agents.")
          .foregroundColor(.secondary)
      }

      Section {
        AgentTypePicker(label: "Agent", selection: $selectedAgentType)

        if isCustomAgent {
          LabeledContent("Command") {
            TextField("", text: commandBinding)
              .textFieldStyle(.roundedBorder)
              .font(.system(.body, design: .monospaced))
          }
        }

        LabeledContent("Options") {
          TextField("", text: optionsBinding)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
        }
      } header: {
        Text("Agent Options")
      } footer: {
        let fullCommand = settings.getFullCommand(for: selectedAgentType)
        if !fullCommand.isEmpty {
          Text("Full command: \(fullCommand)")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
        } else if isCustomAgent {
          Text("Enter a command for this custom agent")
            .foregroundColor(.secondary)
        }
      }

      Section {
        OpenWithAppPicker(label: "Default app", selection: $settings.defaultOpenWithApp)
      } header: {
        Text("Open With (⌘⇧O)")
      } footer: {
        Text("The app to open when pressing ⌘⇧O on the active agent.")
          .foregroundColor(.secondary)
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .padding()
  }

  private func selectSourceFolder() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = false
    panel.message = "Select your source folder containing git repositories"
    panel.prompt = "Select"

    // Start in current source folder if set, otherwise home
    if settings.hasValidSourceBaseFolder {
      panel.directoryURL = URL(fileURLWithPath: settings.expandedSourceBaseFolder)
    } else {
      panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    }

    if panel.runModal() == .OK, let url = panel.url {
      settings.sourceBaseFolder = PathUtils.shortened(url.path)
    }
  }
}
