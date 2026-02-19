import SwiftUI

struct MCPSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared

  var body: some View {
    Form {
      Section {
        Text("The MCP server enables agents to exchange messages and interact with Skwad.")
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
    .scrollDisabled(true)
    .padding()
  }
}
