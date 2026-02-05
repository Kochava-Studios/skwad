import SwiftUI
import Sparkle

enum SettingsTab: Int, CaseIterable {
  case general, coding, terminal, voice, mcp
}

/// Modifier key codes used for push-to-talk configuration
enum ModifierKeyCode: UInt16, CaseIterable {
  case rightCommand = 54
  case leftCommand = 55
  case leftShift = 56
  case capsLock = 57
  case leftOption = 58
  case leftControl = 59
  case rightShift = 60
  case rightOption = 61
  case rightControl = 62
  case function = 63

  var displayName: String {
    switch self {
    case .rightCommand: "Right Command"
    case .leftCommand: "Left Command"
    case .leftShift: "Left Shift"
    case .rightShift: "Right Shift"
    case .leftOption: "Left Option"
    case .rightOption: "Right Option"
    case .leftControl: "Left Control"
    case .rightControl: "Right Control"
    case .capsLock: "Caps Lock"
    case .function: "Fn"
    }
  }

  static func name(for keyCode: Int) -> String {
    ModifierKeyCode(rawValue: UInt16(keyCode))?.displayName ?? "Key \(keyCode)"
  }

  static let allKeyCodes: Set<UInt16> = Set(allCases.map(\.rawValue))
}

struct SettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  @State private var selectedTab: SettingsTab = .general
  
  var body: some View {
    TabView(selection: $selectedTab) {
      GeneralSettingsView()
        .tag(SettingsTab.general)
        .tabItem {
          Label("General", systemImage: "gear")
        }
      
      CodingSettingsView()
        .tag(SettingsTab.coding)
        .tabItem {
          Label("Coding", systemImage: "chevron.left.forwardslash.chevron.right")
        }
      
      MCPSettingsView()
        .tag(SettingsTab.mcp)
        .tabItem {
          Label("MCP", systemImage: "message.badge.waveform")
        }
      
      VoiceSettingsView()
        .tag(SettingsTab.voice)
        .tabItem {
          Label("Voice", systemImage: "mic")
        }
      TerminalSettingsView()
        .tag(SettingsTab.terminal)
        .tabItem {
          Label("Terminal", systemImage: "terminal")
        }
      
      
    }
    .frame(width: 550)
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct GeneralSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  private let updater = UpdaterManager.shared.updater
  @State private var automaticallyChecksForUpdates: Bool = true

  private var appearanceFooter: String {
    switch AppearanceMode(rawValue: settings.appearanceMode) {
    case .auto:
      return "Derives light/dark mode from terminal background color."
    case .system:
      return "Follows your macOS system appearance setting."
    case .light:
      return "Always use light appearance."
    case .dark:
      return "Always use dark appearance."
    case .none:
      return ""
    }
  }
  
  var body: some View {
    Form {
      Section {
        Picker("Appearance", selection: $settings.appearanceMode) {
          ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
            Text(mode.displayName).tag(mode.rawValue)
          }
        }
      } header: {
        Text("Appearance")
      } footer: {
        Text(appearanceFooter)
          .foregroundColor(.secondary)
      }
      
      Section {
        Toggle("Restore agents on launch", isOn: $settings.restoreLayoutOnLaunch)
        Toggle("Keep running in menu bar when closed", isOn: $settings.keepInMenuBar)
      } header: {
        Text("Startup")
      } footer: {
        if settings.keepInMenuBar {
          Text("Closing the window or pressing ⌘Q will hide Skwad to the menu bar. Use the menu bar icon to show the window or quit.")
            .foregroundColor(.secondary)
        }
      }

      Section {
        Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
          .onChange(of: automaticallyChecksForUpdates) { _, newValue in
            updater.automaticallyChecksForUpdates = newValue
          }
      } header: {
        Text("Updates")
      }

    }
    .formStyle(.grouped)
    .padding()
    .onAppear {
      automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }
  }
}

struct AgentCommandOption: Identifiable {
  let id: String
  let name: String
  let icon: String?      // Asset image name
  let systemIcon: String? // SF Symbol fallback
  let needsLongStartup: Bool  // true for slow-starting agents like Gemini
  
  init(_ id: String, _ name: String, icon: String? = nil, systemIcon: String? = nil, needsLongStartup: Bool = false) {
    self.id = id
    self.name = name
    self.icon = icon
    self.systemIcon = systemIcon
    self.needsLongStartup = needsLongStartup
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

struct TerminalSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared

  @State private var backgroundColor: Color
  @State private var foregroundColor: Color

  private let terminalEngines = [
    ("ghostty", "Ghostty (GPU-accelerated)"),
    ("swiftterm", "SwiftTerm")
  ]

  private let monospaceFonts = [
    "SF Mono",
    "Menlo",
    "Monaco",
    "Courier New",
    "Andale Mono",
    "JetBrains Mono",
    "Fira Code",
    "Source Code Pro",
    "IBM Plex Mono",
    "Hack",
    "Inconsolata"
  ]
  
  private var availableFonts: [String] {
    let fontManager = NSFontManager.shared
    let allFonts = fontManager.availableFontFamilies
    return monospaceFonts.filter { allFonts.contains($0) }
  }
  
  init() {
    let s = AppSettings.shared
    _backgroundColor = State(initialValue: s.terminalBackgroundColor)
    _foregroundColor = State(initialValue: s.terminalForegroundColor)
  }
  
  var body: some View {
    Form {
      Section {
        Picker("Engine", selection: $settings.terminalEngine) {
          ForEach(terminalEngines, id: \.0) { engine in
            Text(engine.1).tag(engine.0)
          }
        }
      } header: {
        Text("Terminal Engine")
      } footer: {
        Text("Changing terminal engine requires restarting Skwad.")
          .foregroundColor(.secondary)
      }

      if settings.terminalEngine == "ghostty" {
        ghosttySettings
      } else {
        swiftTermSettings
      }
    }
    .formStyle(.grouped)
    .padding()
  }
  
  @ViewBuilder
  private var ghosttySettings: some View {
    Section {
      HStack {
        Text("Configuration")
        Spacer()
        Text(settings.ghosttyConfigPath)
          .foregroundColor(.secondary)
          .font(.system(.body, design: .monospaced))
      }
      
      if settings.ghosttyBackgroundColor != nil {
        HStack {
          Text("Background color")
          Spacer()
          RoundedRectangle(cornerRadius: 4)
            .fill(settings.effectiveBackgroundColor)
            .frame(width: 24, height: 24)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
      }
    } header: {
      Text("Ghostty")
    } footer: {
      Text("Font, colors, and theme are loaded from your Ghostty configuration file.")
        .foregroundColor(.secondary)
    }
  }
  
  @ViewBuilder
  private var swiftTermSettings: some View {
    Section {
      Picker("Font", selection: $settings.terminalFontName) {
        ForEach(availableFonts, id: \.self) { font in
          Text(font)
            .font(.custom(font, size: 13))
            .tag(font)
        }
      }
      
      HStack {
        Text("Size")
        Spacer()
        Slider(value: $settings.terminalFontSize, in: 9...24, step: 1) {
          Text("Size")
        }
        .frame(width: 150)
        Text("\(Int(settings.terminalFontSize)) pt")
          .monospacedDigit()
          .frame(width: 45, alignment: .trailing)
      }
    } header: {
      Text("Font")
    }
    
    Section {
      ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
        .onChange(of: backgroundColor) { _, newValue in
          settings.terminalBackgroundColor = newValue
        }
      
      ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: false)
        .onChange(of: foregroundColor) { _, newValue in
          settings.terminalForegroundColor = newValue
        }
    } header: {
      Text("Colors")
    }
    
    Section {
      TerminalPreviewView()
        .frame(height: 80)
    } header: {
      Text("Preview")
    }
  }
}

struct TerminalPreviewView: View {
  @ObservedObject private var settings = AppSettings.shared
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 8)
        .fill(settings.terminalBackgroundColor)
      
      VStack(alignment: .leading, spacing: 4) {
        Text("$ claude")
        Text("Agent started...")
        Text("~/Projects/my-app")
      }
      .font(.custom(settings.terminalFontName, size: settings.terminalFontSize))
      .foregroundColor(settings.terminalForegroundColor)
      .padding(12)
    }
  }
}

struct MCPSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  
  var body: some View {
    Form {
      Section {
        Text("The MCP server enables agent-to-agent communication. Agents can send messages to each other, broadcast to all agents, and check their inbox. When an agent becomes idle, it is automatically notified of any pending messages.")
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } header: {
        Text("About")
      }
      
      Section {
        Toggle("Enable MCP server", isOn: $settings.mcpServerEnabled)
        
        LabeledContent("Port") {
          TextField("", value: $settings.mcpServerPort, format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(width: 80)
        }
        
        LabeledContent("URL") {
          Text(settings.mcpServerURL)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
            .textSelection(.enabled)
        }
      } header: {
        Text("Server Settings")
      }
      
      Section {
        VStack(spacing: 0) {
          MCPCommandView(serverURL: settings.mcpServerURL)
        }
        .padding(.vertical, 4)
      } header: {
        Text("Installation Command")
      } footer: {
        Text("Select an agent from the dropdown, then copy and run the command in your terminal to connect it to Skwad's MCP server.")
          .foregroundColor(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
  }
}

struct VoiceSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared
  @State private var pushToTalk = PushToTalkMonitor.shared
  @State private var isRecordingKey = false
  
  private let voiceEngines = [
    ("apple", "Apple SpeechAnalyzer")
  ]
  
  var body: some View {
    Form {
      Section {
        Text("Voice input allows you to speak commands to your agents using push-to-talk. Hold the configured key to record, release to stop.")
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } header: {
        Text("About")
      }
      
      Section {
        Toggle("Enable voice input", isOn: $settings.voiceEnabled)
        
        Picker("Engine", selection: $settings.voiceEngine) {
          ForEach(voiceEngines, id: \.0) { engine in
            Text(engine.1).tag(engine.0)
          }
        }
        .disabled(!settings.voiceEnabled)
      } header: {
        Text("Engine")
      } footer: {
        Text("Uses on-device speech recognition. No data is sent to the cloud.")
          .foregroundColor(.secondary)
      }
      
      Section {
        LabeledContent("Push-to-Talk Key") {
          Button(isRecordingKey ? "Press any key..." : keyName(for: settings.voicePushToTalkKey)) {
            isRecordingKey = true
          }
          .buttonStyle(.bordered)
          .background(
            KeyRecorderView(isRecording: $isRecordingKey) { keyCode in
              settings.voicePushToTalkKey = Int(keyCode)
            }
          )
        }
        .disabled(!settings.voiceEnabled)
        
        Toggle("Auto-insert transcription", isOn: $settings.voiceAutoInsert)
          .disabled(!settings.voiceEnabled)
      } header: {
        Text("Input")
      } footer: {
        Text(settings.voiceAutoInsert
             ? "Transcribed text will be automatically inserted into the terminal."
             : "Transcribed text will be shown in a popup for review before insertion.")
        .foregroundColor(.secondary)
      }
    }
    .formStyle(.grouped)
    .padding()
    .onChange(of: isRecordingKey) { _, recording in
      // Stop push-to-talk monitor while recording a new key
      if recording {
        pushToTalk.stop()
      } else if settings.voiceEnabled {
        pushToTalk.start()
      }
    }
  }
  
  private func keyName(for keyCode: Int) -> String {
    ModifierKeyCode.name(for: keyCode)
  }
}

/// Hidden view that captures key events for recording push-to-talk key
struct KeyRecorderView: NSViewRepresentable {
  @Binding var isRecording: Bool
  let onKeyRecorded: (UInt16) -> Void
  
  func makeNSView(context: Context) -> NSView {
    let view = KeyRecorderNSView()
    view.onKeyRecorded = { keyCode in
      onKeyRecorded(keyCode)
      isRecording = false
    }
    return view
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {
    guard let view = nsView as? KeyRecorderNSView else { return }
    view.isRecording = isRecording
    if isRecording {
      nsView.window?.makeFirstResponder(nsView)
    }
  }
}

class KeyRecorderNSView: NSView {
  var isRecording = false
  var onKeyRecorded: ((UInt16) -> Void)?

  override var acceptsFirstResponder: Bool { isRecording }

  override func keyDown(with event: NSEvent) {
    guard isRecording, ModifierKeyCode.allKeyCodes.contains(event.keyCode) else { return }
    onKeyRecorded?(event.keyCode)
  }

  override func flagsChanged(with event: NSEvent) {
    guard isRecording, ModifierKeyCode.allKeyCodes.contains(event.keyCode) else { return }
    onKeyRecorded?(event.keyCode)
  }
}

#Preview {
  SettingsView()
}

