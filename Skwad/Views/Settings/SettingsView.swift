import SwiftUI

enum SettingsTab: Int, CaseIterable {
  case general, coding, autopilot, voice, mcp, terminal
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

      AutopilotSettingsView()
        .tag(SettingsTab.autopilot)
        .tabItem {
          Label("Autopilot", systemImage: "autostartstop")
        }

      VoiceSettingsView()
        .tag(SettingsTab.voice)
        .tabItem {
          Label("Voice", systemImage: "mic")
        }

      MCPSettingsView()
        .tag(SettingsTab.mcp)
        .tabItem {
          Label("MCP", systemImage: "message.badge.waveform")
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

#Preview {
  SettingsView()
}
