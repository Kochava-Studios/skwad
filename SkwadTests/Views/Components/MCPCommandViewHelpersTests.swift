import XCTest
import Foundation
@testable import Skwad

final class MCPCommandViewHelpersTests: XCTestCase {

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

    let serverURL = "http://localhost:9876"

    // MARK: - Display Command Generation

    func testClaudeShowsInfoMessageForDisplay() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "claude", serverURL: serverURL)
        XCTAssertTrue(command.contains("auto-started"))
        XCTAssertFalse(command.contains("localhost"))
    }

    func testCodexGeneratesAddCommand() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: serverURL)
        XCTAssertEqual(command, "codex mcp add skwad --url http://localhost:9876")
    }

    func testOpencodeGeneratesAddCommandWithURL() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "opencode", serverURL: serverURL)
        XCTAssertTrue(command.contains("opencode mcp add"))
        XCTAssertTrue(command.contains(serverURL))
    }

    func testGeminiGeneratesAddCommandWithTransport() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "gemini", serverURL: serverURL)
        XCTAssertTrue(command.contains("gemini mcp add"))
        XCTAssertTrue(command.contains("--transport http"))
        XCTAssertTrue(command.contains("--scope user"))
        XCTAssertTrue(command.contains(serverURL))
    }

    func testCopilotShowsInfoMessage() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "copilot", serverURL: serverURL)
        XCTAssertTrue(command.contains("auto-started"))
    }

    func testUnknownAgentReturnsEmpty() {
        let command = MCPCommandViewHelpersTests.mcpCommand(for: "unknown", serverURL: serverURL)
        XCTAssertEqual(command, "")
    }

    // MARK: - Copy Command Generation

    func testClaudeCopyCommandIsValidCLI() {
        let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "claude", serverURL: serverURL)
        XCTAssertEqual(command, "claude mcp add --transport http --scope user skwad http://localhost:9876")
    }

    func testOpencodeCopyCommandIsSimplified() {
        let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "opencode", serverURL: serverURL)
        XCTAssertEqual(command, "opencode mcp add")
    }

    func testCopilotCopyCommandIsEmpty() {
        let command = MCPCommandViewHelpersTests.mcpCommandCopy(for: "copilot", serverURL: serverURL)
        XCTAssertEqual(command, "")
    }

    func testCodexCopyMatchesDisplay() {
        let display = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: serverURL)
        let copy = MCPCommandViewHelpersTests.mcpCommandCopy(for: "codex", serverURL: serverURL)
        XCTAssertEqual(copy, display)
    }

    func testGeminiCopyMatchesDisplay() {
        let display = MCPCommandViewHelpersTests.mcpCommand(for: "gemini", serverURL: serverURL)
        let copy = MCPCommandViewHelpersTests.mcpCommandCopy(for: "gemini", serverURL: serverURL)
        XCTAssertEqual(copy, display)
    }

    // MARK: - Server URL Substitution

    func testDifferentURLsAreSubstitutedCorrectly() {
        let url1 = "http://localhost:8080"
        let url2 = "http://192.168.1.100:9999"

        let cmd1 = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: url1)
        let cmd2 = MCPCommandViewHelpersTests.mcpCommand(for: "codex", serverURL: url2)

        XCTAssertTrue(cmd1.contains("8080"))
        XCTAssertTrue(cmd2.contains("192.168.1.100"))
        XCTAssertTrue(cmd2.contains("9999"))
    }
}
