import Testing
import Foundation
@testable import Skwad

@Suite("MCPCommandView Helpers")
struct MCPCommandViewHelpersTests {

    // MARK: - MCP Command Generation

    /// Helper that mirrors the mcpCommand logic from MCPCommandView
    static func mcpCommand(for agent: String, serverURL: String) -> String {
        switch agent {
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

    /// Helper that mirrors the mcpCommandCopy logic from MCPCommandView
    static func mcpCommandCopy(for agent: String, serverURL: String) -> String {
        switch agent {
        case "claude":
            return "claude mcp add --transport http --scope user skwad \(serverURL)"
        case "opencode":
            return "opencode mcp add"
        case "copilot":
            return ""
        default:
            return mcpCommand(for: agent, serverURL: serverURL)
        }
    }

    @Suite("Display Command Generation")
    struct DisplayCommandTests {
        let serverURL = "http://localhost:9876"

        @Test("claude shows info message for display")
        func claudeShowsInfoMessage() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "claude", serverURL: serverURL)
            #expect(command.contains("auto-started"))
            #expect(!command.contains("localhost"))
        }

        @Test("codex generates add command")
        func codexGeneratesAddCommand() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: serverURL)
            #expect(command == "codex mcp add skwad --url http://localhost:9876")
        }

        @Test("opencode generates add command with URL")
        func opencodeGeneratesAddCommand() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "opencode", serverURL: serverURL)
            #expect(command.contains("opencode mcp add"))
            #expect(command.contains(serverURL))
        }

        @Test("gemini generates add command with transport")
        func geminiGeneratesAddCommand() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "gemini", serverURL: serverURL)
            #expect(command.contains("gemini mcp add"))
            #expect(command.contains("--transport http"))
            #expect(command.contains("--scope user"))
            #expect(command.contains(serverURL))
        }

        @Test("copilot shows info message")
        func copilotShowsInfoMessage() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "copilot", serverURL: serverURL)
            #expect(command.contains("auto-started"))
        }

        @Test("unknown agent returns empty")
        func unknownAgentReturnsEmpty() {
            let command = MCPCommandViewHelpersTests.mcpCommand(for: "unknown", serverURL: serverURL)
            #expect(command == "")
        }
    }

    @Suite("Copy Command Generation")
    struct CopyCommandTests {
        let serverURL = "http://localhost:9876"

        @Test("claude copy command is valid CLI")
        func claudeCopyCommandIsValidCLI() {
            let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "claude", serverURL: serverURL)
            #expect(command == "claude mcp add --transport http --scope user skwad http://localhost:9876")
        }

        @Test("opencode copy command is simplified")
        func opencodeCopyCommandIsSimplified() {
            let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "opencode", serverURL: serverURL)
            #expect(command == "opencode mcp add")
        }

        @Test("copilot copy command is empty")
        func copilotCopyCommandIsEmpty() {
            let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "copilot", serverURL: serverURL)
            #expect(command == "")
        }

        @Test("codex copy command matches display command")
        func codexCopyMatchesDisplay() {
            let display = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: serverURL)
            let copy = MCPCommandViewHelpersTests.mcpCommandCopy(for: "codex", serverURL: serverURL)
            #expect(copy == display)
        }

        @Test("gemini copy command matches display command")
        func geminiCopyMatchesDisplay() {
            let display = MCPCommandViewHelpersTests.mcpCommand(for: "gemini", serverURL: serverURL)
            let copy = MCPCommandViewHelpersTests.mcpCommandCopy(for: "gemini", serverURL: serverURL)
            #expect(copy == display)
        }
    }

    @Suite("Server URL Substitution")
    struct ServerURLSubstitutionTests {

        @Test("different URLs are substituted correctly")
        func differentURLsSubstituted() {
            let url1 = "http://localhost:8080"
            let url2 = "http://192.168.1.100:9999"

            let cmd1 = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: url1)
            let cmd2 = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: url2)

            #expect(cmd1.contains("8080"))
            #expect(cmd2.contains("192.168.1.100"))
            #expect(cmd2.contains("9999"))
        }
    }
}
