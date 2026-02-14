import SwiftUI

/// Reusable component to display MCP add command with agent picker and copy button
struct MCPCommandView: View {
    let serverURL: String
    var fontSize: Font = .body
    var backgroundColor: Color? = nil
    var iconSize: CGFloat = 16
    @State private var selectedAgent: String = "claude"
    @State private var copied = false
    
    private var mcpCommand: String {
        switch selectedAgent {
        case "claude":
            return "Skwad MCP Server is auto-started with your agents. Click copy if you want to install it globally."
        case "codex":
            return "codex mcp add skwad --url \(serverURL)"
        case "opencode":
            return "opencode mcp add (skwad / Remote / \(serverURL))"
        case "gemini":
            return "gemini mcp add --transport http skwad \(serverURL) --scope user"
        case "copilot":
            return "Skward MCP server is auto-started with your agents. No manual setup needed."
        default:
            return ""
        }
    }

    private var mcpCommandCopy: String {
        switch selectedAgent {
        case "claude":
            return "claude mcp add --transport http --scope user skwad \(serverURL)"
        case "opencode":
            return "opencode mcp add"
        case "copilot":
            return ""
        default:
            return mcpCommand
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Agent picker - icon only using Menu for better control
            Menu {
                ForEach(availableAgents.filter { $0.id != "custom1" && $0.id != "custom2" && $0.id != "shell" }, id: \.id) { agent in
                    Button {
                        selectedAgent = agent.id
                    } label: {
                        AgentTypePickerContent(agent: agent, iconSize: 16)
                    }
                }
            } label: {
                // Show selected agent icon
                if let agent = availableAgents.first(where: { $0.id == selectedAgent }) {
                    HStack(spacing: 6) {
                        if let icon = agent.icon, let image = NSImage(named: icon) {
                            let scaledImage = image.scalePreservingAspectRatio(
                                targetSize: NSSize(width: iconSize, height: iconSize)
                            )
                            Image(nsImage: scaledImage)
                        } else if let systemIcon = agent.systemIcon {
                            Image(systemName: systemIcon)
                                .font(.system(size: iconSize))
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 50)
            
            // Command text
            let isAutomatic = selectedAgent == "claude" || selectedAgent == "copilot"
            Text(mcpCommand)
                .font(.system(fontSize == .body ? .body : .title3, design: isAutomatic ? .default : .monospaced))
                .foregroundColor(isAutomatic ? .secondary : .primary)
                .textSelection(.enabled)
                .lineLimit(isAutomatic ? 2 : 1)
            
            Spacer()
            
            // Copy button
            Button {
                copyCommand()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copied ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help("Copy command")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor ?? Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(mcpCommandCopy, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

#Preview {
    MCPCommandView(serverURL: "http://localhost:8080/mcp")
        .frame(width: 600)
        .padding()
}
