import Foundation

/// Builds shell commands for agent initialization
///
/// This service centralizes all command construction logic that was previously
/// duplicated across multiple view components (GhosttyHostView, TerminalHostView).
struct TerminalCommandBuilder {
  
  /// Builds the full agent command with MCP tool filtering arguments
  ///
  /// - Parameters:
  ///   - agentType: The type of agent (claude, codex, etc.)
  ///   - settings: The app settings containing user-configured options
  /// - Returns: The complete agent command with all arguments
  static func buildAgentCommand(for agentType: String, settings: AppSettings) -> String {
    let cmd = settings.getCommand(for: agentType)
    let userOpts = settings.getOptions(for: agentType)
    
    guard !cmd.isEmpty else { return "" }
    
    var fullCommand = cmd
    
    // Add MCP-specific arguments if MCP is enabled
    if settings.mcpServerEnabled {
      fullCommand += getMCPArguments(for: agentType, mcpURL: settings.mcpServerURL)
    }
    
    // Add user-provided options last
    if !userOpts.isEmpty {
      fullCommand += " \(userOpts)"
    }
    
    return fullCommand
  }
  
  /// Get MCP-specific arguments for each agent type
  private static func getMCPArguments(for agentType: String, mcpURL: String) -> String {
    switch agentType {
    case "claude":
      let mcpConfig = #"--mcp-config '{"mcpServers":{"skwad":{"type":"http","url":"\#(mcpURL)"}}}'"#
      return " \(mcpConfig) --allowed-tools 'mcp__skwad__*'"
      
    case "gemini":
      return " --allowed-mcp-server-names skwad"
      
    case "copilot":
      // Configure the MCP server and allow all Skwad tools
      let mcpConfig = #"--additional-mcp-config '{"mcpServers":{"skwad":{"type":"http","url":"\#(mcpURL)","tools":["*"]}}}'"#
      let allowedTools = [
        "skwad(register-agent)",
        "skwad(list-agents)",
        "skwad(send-message)",
        "skwad(check-messages)",
        "skwad(broadcast-message)"
      ].map { "--allow-tool '\($0)'" }.joined(separator: " ")
      return " \(mcpConfig) \(allowedTools)"
      
    default:
      return ""
    }
  }
  
  /// Builds the initialization command that navigates to the folder,
  /// clears the screen, and launches the agent.
  ///
  /// The command is prefixed with a space to prevent shell history pollution
  /// (requires HISTCONTROL=ignorespace in bash or equivalent in other shells).
  ///
  /// - Parameters:
  ///   - folder: The working directory for the agent
  ///   - agentCommand: The full agent command to execute
  /// - Returns: The complete shell command string
  static func buildInitializationCommand(folder: String, agentCommand: String) -> String {
    // Prefix with space to prevent shell history
    // Note: zsh ignores by default, bash requires HISTCONTROL=ignorespace
    return " cd '\(folder)' && clear && \(agentCommand)"
  }
  
  /// Gets the default shell executable path
  static func getDefaultShell() -> String {
    return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
  }
}
