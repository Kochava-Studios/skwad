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
            ("Register with the skwad", command.range(of: "Register with the skwad")?.lowerBound)
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

    func testSupportsSystemPromptOnlyForClaude() {
        XCTAssertTrue(TerminalCommandBuilder.supportsSystemPrompt(agentType: "claude"))
        XCTAssertFalse(TerminalCommandBuilder.supportsSystemPrompt(agentType: "codex"))
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
        XCTAssertTrue(command.contains("Register with the skwad"))

        settings.mcpServerEnabled = originalMCP
    }

    @MainActor
    func testCodexRegistrationUsesUserPrompt() {
        let settings = AppSettings.shared
        let originalMCP = settings.mcpServerEnabled

        settings.mcpServerEnabled = true

        let agentId = UUID()
        let command = TerminalCommandBuilder.buildAgentCommand(
            for: "codex",
            settings: settings,
            agentId: agentId
        )

        // Codex uses positional argument (no flag)
        XCTAssertTrue(command.contains(agentId.uuidString))
        XCTAssertTrue(command.contains("Register with the skwad"))
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
}
