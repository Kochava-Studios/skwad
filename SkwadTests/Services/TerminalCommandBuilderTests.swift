import XCTest
@testable import Skwad

final class TerminalCommandBuilderTests: XCTestCase {

    // MARK: - Basic Command Building

    @MainActor
    func testBuildAgentCommandReturnsBaseCommandForUnknownAgent() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(for: "unknownagent", settings: settings)
        XCTAssertEqual(command, "unknownagent")

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testBuildAgentCommandReturnsEmptyForEmptyCommand() {
        let settings = AppSettings.shared
        let originalCommand = settings.customAgent1Command
        settings.customAgent1Command = ""

        let command = TerminalCommandBuilder.buildAgentCommand(for: "custom1", settings: settings)
        XCTAssertEqual(command, "")

        settings.customAgent1Command = originalCommand
    }

    // MARK: - User Options Ordering

    @MainActor
    func testUserOptionsAddedBeforeMCPArguments() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        let originalOptions = settings.agentOptions_claude

        settings.mcpServerEnabled = true
        settings.agentOptions_claude = "--settings ~/.claude/test.json"

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID()
        )

        // User options should come before MCP config
        let settingsIndex = command.range(of: "--settings")?.lowerBound
        let mcpIndex = command.range(of: "--mcp-config")?.lowerBound

        XCTAssertNotNil(settingsIndex, "Should contain --settings")
        XCTAssertNotNil(mcpIndex, "Should contain --mcp-config")
        XCTAssertTrue(settingsIndex! < mcpIndex!, "User options should come before MCP arguments")

        settings.mcpServerEnabled = originalMCP
        settings.agentOptions_claude = originalOptions
    }

    @MainActor
    func testUserOptionsAddedBeforeRegistrationArguments() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        let originalOptions = settings.agentOptions_claude

        settings.mcpServerEnabled = true
        settings.agentOptions_claude = "--model opus"

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID()
        )

        // User options should come before registration arguments
        let modelIndex = command.range(of: "--model opus")?.lowerBound
        let appendIndex = command.range(of: "--append-system-prompt")?.lowerBound

        XCTAssertNotNil(modelIndex, "Should contain --model opus")
        XCTAssertNotNil(appendIndex, "Should contain --append-system-prompt")
        XCTAssertTrue(modelIndex! < appendIndex!, "User options should come before registration arguments")

        settings.mcpServerEnabled = originalMCP
        settings.agentOptions_claude = originalOptions
    }

    @MainActor
    func testCommandOrderWithAllComponents() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        let originalOptions = settings.agentOptions_claude

        settings.mcpServerEnabled = true
        settings.agentOptions_claude = "--settings ~/.claude/test.json"

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId
        )

        // Expected order: claude --settings ... --mcp-config ... --allowed-tools ... --append-system-prompt ... "Register..."
        let parts = [
            ("claude", command.range(of: "claude")?.lowerBound),
            ("--settings", command.range(of: "--settings")?.lowerBound),
            ("--mcp-config", command.range(of: "--mcp-config")?.lowerBound),
            ("--allowed-tools", command.range(of: "--allowed-tools")?.lowerBound),
            ("--append-system-prompt", command.range(of: "--append-system-prompt")?.lowerBound),
            ("List other agents", command.range(of: "List other agents")?.lowerBound)
        ]

        // Verify all parts exist
        for (name, index) in parts {
            XCTAssertNotNil(index, "Command should contain \(name)")
        }

        // Verify order
        for i in 0..<(parts.count - 1) {
            if let current = parts[i].1, let next = parts[i + 1].1 {
                XCTAssertTrue(current < next, "\(parts[i].0) should come before \(parts[i + 1].0)")
            }
        }

        settings.mcpServerEnabled = originalMCP
        settings.agentOptions_claude = originalOptions
    }

    // MARK: - MCP Arguments

    @MainActor
    func testMCPArgumentsNotAddedWhenDisabled() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(for: "claude", settings: settings)

        XCTAssertFalse(command.contains("--mcp-config"))
        XCTAssertFalse(command.contains("--allowed-tools"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testMCPArgumentsAddedForClaude() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(for: "claude", settings: settings)

        XCTAssertTrue(command.contains("--mcp-config"))
        XCTAssertTrue(command.contains("skwad"))
        XCTAssertTrue(command.contains("--allowed-tools"))
        XCTAssertTrue(command.contains("mcp__skwad__*"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testMCPArgumentsAddedForGemini() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(for: "gemini", settings: settings)

        XCTAssertTrue(command.contains("--allowed-mcp-server-names"))
        XCTAssertTrue(command.contains("skwad"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testMCPArgumentsAddedForCopilot() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(for: "copilot", settings: settings)

        XCTAssertTrue(command.contains("--additional-mcp-config"))
        XCTAssertTrue(command.contains("skwad"))
        XCTAssertTrue(command.contains("--allow-tool"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Inline Registration

    func testSupportsInlineRegistrationForClaude() {
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "claude"))
    }

    func testSupportsInlineRegistrationForCodex() {
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "codex"))
    }

    func testSupportsInlineRegistrationForOpencode() {
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "opencode"))
    }

    func testSupportsInlineRegistrationForGemini() {
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "gemini"))
    }

    func testSupportsInlineRegistrationForCopilot() {
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "copilot"))
    }

    func testSupportsInlineRegistrationForShell() {
        // Shell returns true to skip registration prompts entirely
        XCTAssertTrue(TerminalCommandBuilder.supportsInlineRegistration(agentType: "shell"))
    }

    func testSupportsSystemPromptForClaudeAndCodex() {
        XCTAssertTrue(TerminalCommandBuilder.supportsSystemPrompt(agentType: "claude"))
        XCTAssertTrue(TerminalCommandBuilder.supportsSystemPrompt(agentType: "codex"))
        XCTAssertFalse(TerminalCommandBuilder.supportsSystemPrompt(agentType: "gemini"))
    }

    @MainActor
    func testClaudeRegistrationUsesSystemPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId
        )

        XCTAssertTrue(command.contains("--append-system-prompt"))
        XCTAssertTrue(command.contains(agentId.uuidString))
        XCTAssertTrue(command.contains("List other agents"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCodexRegistrationUsesSystemAndUserPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            agentId: agentId
        )

        // Codex uses -c developer_instructions for system prompt + positional user prompt
        XCTAssertTrue(command.contains(agentId.uuidString))
        XCTAssertTrue(command.contains("developer_instructions"))
        XCTAssertTrue(command.contains("List other agents"))
        XCTAssertFalse(command.contains("--append-system-prompt"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testOpencodeRegistrationUsesPromptFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "opencode",
            settings: settings,
            agentId: agentId
        )

        XCTAssertTrue(command.contains("--prompt"))
        XCTAssertTrue(command.contains(agentId.uuidString))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testGeminiRegistrationUsesPromptInteractiveFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "gemini",
            settings: settings,
            agentId: agentId
        )

        XCTAssertTrue(command.contains("--prompt-interactive"))
        XCTAssertTrue(command.contains(agentId.uuidString))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCopilotRegistrationUsesInteractiveFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "copilot",
            settings: settings,
            agentId: agentId
        )

        XCTAssertTrue(command.contains("--interactive"))
        XCTAssertTrue(command.contains(agentId.uuidString))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testNoRegistrationWithoutAgentId() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: nil
        )

        XCTAssertFalse(command.contains("--append-system-prompt"))
        XCTAssertFalse(command.contains("Register with the skwad"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Initialization Command

    func testBuildInitializationCommandIncludesCdAndClear() {
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "claude"
        )

        XCTAssertTrue(command.contains("cd '/path/to/project'"))
        XCTAssertTrue(command.contains("clear"))
        XCTAssertTrue(command.contains("claude"))
    }

    func testBuildInitializationCommandPrefixedWithSpace() {
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "claude"
        )

        // Should start with space to avoid shell history
        XCTAssertTrue(command.hasPrefix(" "))
    }

    func testBuildInitializationCommandHandlesSpecialCharactersInPath() {
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/with spaces/and'quotes",
            agentCommand: "claude"
        )

        // Path should be quoted
        XCTAssertTrue(command.contains("'/path/with spaces/and'quotes'"))
    }

    func testBuildInitializationCommandWithEmptyAgentCommand() {
        // Shell mode: just cd and clear, no agent command
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: ""
        )

        XCTAssertTrue(command.contains("cd '/path/to/project'"))
        XCTAssertTrue(command.contains("clear"))
        XCTAssertFalse(command.contains("&&  ") || command.hasSuffix("&& "))  // No trailing &&
        XCTAssertEqual(command, " cd '/path/to/project' && clear")
    }

    // MARK: - Shell Agent Type

    @MainActor
    func testShellAgentTypeReturnsEmptyCommand() {
        let settings = AppSettings.shared
        let command = TerminalCommandBuilder.buildAgentCommand(for: "shell", settings: settings)
        XCTAssertEqual(command, "")
    }

    @MainActor
    func testShellAgentTypeIgnoresMCPSettings() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "shell",
            settings: settings,
            agentId: UUID()
        )

        XCTAssertEqual(command, "")
        XCTAssertFalse(command.contains("--mcp-config"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testShellAgentTypeWithCustomCommand() {
        let settings = AppSettings.shared

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "shell",
            settings: settings,
            shellCommand: "npm run build"
        )

        XCTAssertEqual(command, "npm run build")
    }

    @MainActor
    func testShellAgentTypeWithCustomCommandIgnoresMCP() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "shell",
            settings: settings,
            agentId: UUID(),
            shellCommand: "python script.py"
        )

        XCTAssertEqual(command, "python script.py")
        XCTAssertFalse(command.contains("--mcp-config"))

        settings.mcpServerEnabled = originalMCP
    }

    func testBuildInitializationCommandWithShellCommand() {
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "npm run dev"
        )

        XCTAssertTrue(command.contains("cd '/path/to/project'"))
        XCTAssertTrue(command.contains("clear"))
        XCTAssertTrue(command.contains("npm run dev"))
        XCTAssertEqual(command, " cd '/path/to/project' && clear && npm run dev")
    }

    // MARK: - SKWAD_AGENT_ID Env Var

    func testBuildInitializationCommandInjectsAgentIdEnvVar() {
        let agentId = UUID()
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "claude",
            agentId: agentId
        )

        XCTAssertTrue(command.contains("SKWAD_AGENT_ID=\(agentId.uuidString) claude"))
    }

    func testBuildInitializationCommandOmitsAgentIdWhenNil() {
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "claude"
        )

        XCTAssertFalse(command.contains("SKWAD_AGENT_ID"))
    }

    func testBuildInitializationCommandNoAgentIdForShellMode() {
        let agentId = UUID()
        let command = TerminalCommandBuilder.buildInitializationCommand(
            folder: "/path/to/project",
            agentCommand: "",
            agentId: agentId
        )

        // Shell mode: no agent command, no env var
        XCTAssertFalse(command.contains("SKWAD_AGENT_ID"))
        XCTAssertEqual(command, " cd '/path/to/project' && clear")
    }

    // MARK: - Default Shell

    func testGetDefaultShellReturnsShellEnvOrZsh() {
        let shell = TerminalCommandBuilder.getDefaultShell()

        // Should return SHELL env var or fallback to /bin/zsh
        XCTAssertFalse(shell.isEmpty)
        XCTAssertTrue(shell.hasPrefix("/"))
    }

    // MARK: - Edge Cases

    @MainActor
    func testEmptyUserOptionsDoesNotAddExtraSpace() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        let originalOptions = settings.agentOptions_claude

        settings.mcpServerEnabled = false
        settings.agentOptions_claude = ""

        let command = TerminalCommandBuilder.buildAgentCommand(for: "claude", settings: settings)

        // Should just be "claude" without trailing space
        XCTAssertEqual(command, "claude")

        settings.mcpServerEnabled = originalMCP
        settings.agentOptions_claude = originalOptions
    }

    @MainActor
    func testWhitespaceOnlyUserOptionsAreIncluded() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        let originalOptions = settings.agentOptions_claude

        settings.mcpServerEnabled = false
        settings.agentOptions_claude = "   "

        let command = TerminalCommandBuilder.buildAgentCommand(for: "claude", settings: settings)

        // Whitespace-only options are still added (caller's responsibility to trim)
        XCTAssertEqual(command, "claude    ")

        settings.mcpServerEnabled = originalMCP
        settings.agentOptions_claude = originalOptions
    }

    // MARK: - Resume Session

    @MainActor
    func testResumeSessionAddsResumeFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let sessionId = "abc-123-def"
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            resumeSessionId: sessionId
        )

        XCTAssertTrue(command.contains("--resume abc-123-def"))
        XCTAssertFalse(command.contains("--fork-session"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testForkSessionAddsResumeAndForkFlags() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let sessionId = "abc-123-def"
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            resumeSessionId: sessionId,
            forkSession: true
        )

        XCTAssertTrue(command.contains("--resume abc-123-def"))
        XCTAssertTrue(command.contains("--fork-session"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testResumeIgnoredForNonResumableAgent() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "opencode",
            settings: settings,
            resumeSessionId: "abc-123"
        )

        XCTAssertFalse(command.contains("--resume"))
        XCTAssertFalse(command.contains("resume"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testResumeSkipsUserPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID(),
            resumeSessionId: "abc-123"
        )

        // Should have system prompt but NOT user prompt
        XCTAssertTrue(command.contains("--append-system-prompt"))
        XCTAssertFalse(command.contains("List other agents"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testForkAlsoSkipsUserPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID(),
            resumeSessionId: "abc-123",
            forkSession: true
        )

        XCTAssertTrue(command.contains("--append-system-prompt"))
        XCTAssertFalse(command.contains("List other agents"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testNoResumeIncludesUserPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID()
        )

        XCTAssertTrue(command.contains("List other agents"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Codex Resume (subcommand)

    @MainActor
    func testCodexResumeUsesSubcommand() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            resumeSessionId: "thread-abc-123"
        )

        XCTAssertTrue(command.contains("resume thread-abc-123"))
        XCTAssertFalse(command.contains("--resume"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCodexForkUsesSubcommand() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            resumeSessionId: "thread-abc-123",
            forkSession: true
        )

        XCTAssertTrue(command.contains("fork thread-abc-123"))
        XCTAssertFalse(command.contains("--fork-session"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Gemini/Copilot Resume (flag)

    @MainActor
    func testGeminiResumeUsesFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "gemini",
            settings: settings,
            resumeSessionId: "session-abc"
        )

        XCTAssertTrue(command.contains("--resume session-abc"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCopilotResumeUsesFlag() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "copilot",
            settings: settings,
            resumeSessionId: "session-abc"
        )

        XCTAssertTrue(command.contains("--resume session-abc"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Resume Skips Registration for No-System-Prompt Agents

    @MainActor
    func testGeminiResumeSkipsRegistration() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "gemini",
            settings: settings,
            agentId: UUID(),
            resumeSessionId: "session-abc"
        )

        XCTAssertFalse(command.contains("--prompt-interactive"))
        XCTAssertFalse(command.contains("Register with the skwad"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCopilotResumeSkipsRegistration() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "copilot",
            settings: settings,
            agentId: UUID(),
            resumeSessionId: "session-abc"
        )

        XCTAssertFalse(command.contains("--interactive"))
        XCTAssertFalse(command.contains("Register with the skwad"))

        settings.mcpServerEnabled = originalMCP
    }

    // MARK: - Persona Instructions

    @MainActor
    func testClaudePersonaInstructionsAppendedToSystemPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId,
            persona: Persona(name: "TDD Expert", instructions: "You are a TDD expert following Kent Beck principles.")
        )

        XCTAssertTrue(command.contains("--append-system-prompt"))
        XCTAssertTrue(command.contains("impersonate TDD Expert"))
        XCTAssertTrue(command.contains("You are a TDD expert following Kent Beck principles."))
        XCTAssertTrue(command.contains(agentId.uuidString))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCodexPersonaInstructionsAppendedToSystemPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            agentId: agentId,
            persona: Persona(name: "Security Auditor", instructions: "You are a security auditor.")
        )

        XCTAssertTrue(command.contains("developer_instructions"))
        XCTAssertTrue(command.contains("You are a security auditor."))
        XCTAssertTrue(command.contains(agentId.uuidString))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testPersonaInstructionsIgnoredWhenMCPDisabled() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = false

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: UUID(),
            persona: Persona(name: "Test", instructions: "Some persona")
        )

        XCTAssertFalse(command.contains("Some persona"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testPersonaInstructionsWithSpecialCharsAreEscaped() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId,
            persona: Persona(name: "Tester", instructions: #"Say "hello!" and use $vars"#)
        )

        // Should contain escaped versions
        XCTAssertTrue(command.contains(#"\""#))    // escaped double quote
        XCTAssertTrue(command.contains(#"\!"#))    // escaped exclamation
        XCTAssertTrue(command.contains(#"\$"#))    // escaped dollar sign

        settings.mcpServerEnabled = originalMCP
    }

    func testShellEscapeHandlesDangerousChars() {
        let input = #"He said "hello!" with $var and `cmd`"#
        let escaped = TerminalCommandBuilder.shellEscape(input)
        XCTAssertEqual(escaped, #"He said \"hello\!\" with \$var and \`cmd\`"#)
    }

    func testShellEscapeHandlesBackslash() {
        let escaped = TerminalCommandBuilder.shellEscape(#"path\to\file"#)
        XCTAssertEqual(escaped, #"path\\to\\file"#)
    }

    func testShellEscapeLeavesSingleQuoteAlone() {
        let escaped = TerminalCommandBuilder.shellEscape("can't stop")
        XCTAssertEqual(escaped, "can't stop")
    }

    func testShellEscapeLeavesPlainTextUnchanged() {
        let input = "You are a TDD expert following Kent Beck principles."
        let escaped = TerminalCommandBuilder.shellEscape(input)
        XCTAssertEqual(escaped, input)
    }

    func testPersonaPromptWrapsNameAndInstructions() {
        let persona = Persona(name: "Kent Beck", instructions: "Follow TDD principles")
        let prompt = TerminalCommandBuilder.personaPrompt(from: persona)
        XCTAssertEqual(prompt, "You are asked to impersonate Kent Beck based on the following instructions: Follow TDD principles")
    }

    func testPersonaPromptReturnsNilForNilPersona() {
        XCTAssertNil(TerminalCommandBuilder.personaPrompt(from: nil))
    }

    func testPersonaPromptReturnsNilForEmptyInstructions() {
        let persona = Persona(name: "Empty", instructions: "")
        XCTAssertNil(TerminalCommandBuilder.personaPrompt(from: persona))
    }

    @MainActor
    func testNilPersonaInstructionsDoNotAlterPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let agentId = UUID()
        let withoutPersona = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId
        )
        let withNilPersona = TerminalCommandBuilder.buildAgentCommand(
            for: "claude",
            settings: settings,
            agentId: agentId,
            persona: nil
        )

        XCTAssertEqual(withoutPersona, withNilPersona)

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCodexResumeKeepsSystemPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled
        settings.mcpServerEnabled = true

        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            agentId: UUID(),
            resumeSessionId: "thread-abc"
        )

        XCTAssertTrue(command.contains("developer_instructions"))
        XCTAssertFalse(command.contains("List other agents"))

        settings.mcpServerEnabled = originalMCP
    }
}
