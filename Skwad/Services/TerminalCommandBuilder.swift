import Foundation

/// Builds shell commands for agent initialization
///
/// See `doc/agent-cli-arguments.md` for CLI argument reference across agents.
///
/// This service centralizes all command construction logic that was previously
/// duplicated across multiple view components (GhosttyHostView, TerminalHostView).
struct TerminalCommandBuilder {
  
  /// Builds the full agent command with MCP tool filtering arguments
  ///
  /// - Parameters:
  ///   - agentType: The type of agent (claude, codex, etc.)
  ///   - settings: The app settings containing user-configured options
  ///   - agentId: The agent's UUID for inline registration (optional)
  ///   - shellCommand: Optional command to run for shell agent type
  /// - Returns: The complete agent command with all arguments
  static func buildAgentCommand(for agentType: String, settings: AppSettings, agentId: UUID? = nil, shellCommand: String? = nil, forkSessionId: String? = nil) -> String {
    // Shell type: return custom command or empty
    if agentType == "shell" {
      return shellCommand ?? ""
    }

    let cmd = settings.getCommand(for: agentType)
    let userOpts = settings.getOptions(for: agentType)

    guard !cmd.isEmpty else { return "" }

    var fullCommand = cmd

    // Add fork session arguments (--resume <id> --fork-session)
    if let sessionId = forkSessionId, canForkConversation(agentType: agentType) {
      fullCommand += " --resume \(sessionId) --fork-session"
    }

    // Add user-provided options first (e.g., --settings)
    if !userOpts.isEmpty {
      fullCommand += " \(userOpts)"
    }

    // Add MCP-specific arguments if MCP is enabled
    if settings.mcpServerEnabled {
      fullCommand += getMCPArguments(for: agentType, mcpURL: settings.mcpServerURL)

      // Add inline registration for supported agents
      if let agentId = agentId {
        fullCommand += getInlineRegistrationArguments(for: agentType, agentId: agentId, isFork: forkSessionId != nil)
      }
    }

    return fullCommand
  }

  // MARK: - Registration Prompt Strings

  /// System prompt for agents that support it (currently none besides Claude)
  private static func registrationSystemPrompt(agentId: UUID) -> String {
    "You are part of a team of agents called a skwad. A skwad is made of high-performing agents who collaborate to achieve complex goals so engage with them: ask for help and in return help them succeed. Your skwad agent ID: \(agentId.uuidString)."
  }

  /// User prompt for inline registration (used by most agents)
  private static func registrationUserPrompt(agentId: UUID) -> String {
    "You are part of a team of agents called a skwad. A skwad is made of high-performing agents who collaborate to achieve complex goals so engage with them: ask for help and in return help them succeed. Your skwad agent ID: \(agentId.uuidString). Register with the skwad"
  }

  // MARK: - Inline Registration

  /// Check if an agent type supports forking a conversation (--resume + --fork-session)
  static func canForkConversation(agentType: String) -> Bool {
    switch agentType {
    case "claude":
      return true
    default:
      return false
    }
  }

  /// Check if an agent type supports resuming a conversation (--resume / --continue)
  static func canResumeConversation(agentType: String) -> Bool {
    switch agentType {
    case "claude":
      return true
    default:
      return false
    }
  }

  /// Check if an agent type uses hook-based activity detection (via plugin)
  /// When true, terminal-level activity tracking is disabled
  static func usesActivityHooks(agentType: String) -> Bool {
    switch agentType {
    case "claude":
      return true
    default:
      return false
    }
  }

  /// Check if an agent type supports system prompt injection
  static func supportsSystemPrompt(agentType: String) -> Bool {
    switch agentType {
    case "claude":
      return true
    default:
      return false
    }
  }

  /// Check if an agent type supports inline registration via command-line arguments
  /// Shell returns true to skip registration prompts entirely
  static func supportsInlineRegistration(agentType: String) -> Bool {
    switch agentType {
    case "claude", "codex", "opencode", "gemini", "copilot", "shell":
      return true
    default:
      return false
    }
  }

  /// Get inline registration arguments for supported agents
  /// See `doc/agent-cli-arguments.md` for CLI argument reference
  private static func getInlineRegistrationArguments(for agentType: String, agentId: UUID, isFork: Bool = false) -> String {
    switch agentType {
    case "claude":
      // Claude: registration is handled by hooks, just inject system prompt
      let systemPrompt = registrationSystemPrompt(agentId: agentId)
      return #" --append-system-prompt "\#(systemPrompt)" "List other agents names and project based on context.""#

    case "codex":
      // Codex: user prompt as last argument (no flag)
      let userPrompt = registrationUserPrompt(agentId: agentId)
      return #" "\#(userPrompt)""#

    case "opencode":
      // OpenCode: --prompt "..."
      let userPrompt = registrationUserPrompt(agentId: agentId)
      return #" --prompt "\#(userPrompt)""#

    case "gemini":
      // Gemini CLI: --prompt-interactive "..."
      let userPrompt = registrationUserPrompt(agentId: agentId)
      return #" --prompt-interactive "\#(userPrompt)""#

    case "copilot":
      // GitHub Copilot: --interactive "..."
      let userPrompt = registrationUserPrompt(agentId: agentId)
      return #" --interactive "\#(userPrompt)""#

    default:
      return ""
    }
  }
  
  /// Get MCP-specific arguments for each agent type
  private static func getMCPArguments(for agentType: String, mcpURL: String) -> String {
    switch agentType {
    case "claude":
      let mcpConfig = #"--mcp-config '{"mcpServers":{"skwad":{"type":"http","url":"\#(mcpURL)"}}}'"#
      var args = " \(mcpConfig) --allowed-tools 'mcp__skwad__*'"
      // Add plugin directory for hook-based activity detection
      if let pluginPath = resolvePluginPath() {
        args += " --plugin-dir \"\(pluginPath)\""
      }
      return args
      
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
  static func buildInitializationCommand(folder: String, agentCommand: String, agentId: UUID? = nil) -> String {
    // Prefix with space to prevent shell history
    // Note: zsh ignores by default, bash requires HISTCONTROL=ignorespace
    if agentCommand.isEmpty {
      // Shell mode: just cd and clear, no agent command
      return " cd '\(folder)' && clear"
    }
    // Inject SKWAD_AGENT_ID env var so hooks can identify the agent
    let envPrefix = agentId != nil ? "SKWAD_AGENT_ID=\(agentId!.uuidString) " : ""
    return " cd '\(folder)' && clear && \(envPrefix)\(agentCommand)"
  }
  
  /// Resolves the plugin directory path.
  /// In release builds, the plugin is bundled inside the app.
  /// In dev builds (Xcode), fall back to the source tree.
  private static func resolvePluginPath() -> String? {
    // Try app bundle first (release / archived builds)
    if let bundled = Bundle.main.url(forResource: "plugin", withExtension: nil)?.path,
       FileManager.default.fileExists(atPath: bundled) {
      return bundled
    }
    // Dev fallback: derive source root from this file's compile-time path
    let sourceFile = #filePath
    let sourceDir = (sourceFile as NSString).deletingLastPathComponent  // .../Skwad/Services
    let projectRoot = ((sourceDir as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
    let devPath = (projectRoot as NSString).appendingPathComponent("plugin")
    if FileManager.default.fileExists(atPath: devPath) {
      return devPath
    }
    return nil
  }

  /// Gets the default shell executable path
  static func getDefaultShell() -> String {
    return ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
  }
}
