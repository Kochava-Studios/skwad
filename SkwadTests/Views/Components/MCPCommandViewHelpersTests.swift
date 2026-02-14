import XCTest
import Foundation
@testable import Skwad

final class MCPCommandViewHelpersTests: XCTestCase {

    let serverURL = "http://localhost:9876"

    // MARK: - Display Command Generation

    func testClaudeShowsInfoMessageForDisplay() {
        let command = MCPCommandView.mcpCommand(for: "claude", serverURL: serverURL)
        XCTAssertTrue(command.contains("auto-started"))
        XCTAssertFalse(command.contains("localhost"))
    }

    func testCodexGeneratesAddCommand() {
        let command = MCPCommandView.mcpCommand(for: "codex", serverURL: serverURL)
        XCTAssertEqual(command, "codex mcp add skwad --url http://localhost:9876")
    }

    func testOpencodeGeneratesAddCommandWithURL() {
        let command = MCPCommandView.mcpCommand(for: "opencode", serverURL: serverURL)
        XCTAssertTrue(command.contains("opencode mcp add"))
        XCTAssertTrue(command.contains(serverURL))
    }

    func testGeminiGeneratesAddCommandWithTransport() {
        let command = MCPCommandView.mcpCommand(for: "gemini", serverURL: serverURL)
        XCTAssertTrue(command.contains("gemini mcp add"))
        XCTAssertTrue(command.contains("--transport http"))
        XCTAssertTrue(command.contains("--scope user"))
        XCTAssertTrue(command.contains(serverURL))
    }

    func testCopilotShowsInfoMessage() {
        let command = MCPCommandView.mcpCommand(for: "copilot", serverURL: serverURL)
        XCTAssertTrue(command.contains("auto-started"))
    }

    func testUnknownAgentReturnsEmpty() {
        let command = MCPCommandView.mcpCommand(for: "unknown", serverURL: serverURL)
        XCTAssertEqual(command, "")
    }

    // MARK: - Copy Command Generation

    func testClaudeCopyCommandIsValidCLI() {
        let command = MCPCommandView.mcpCommandCopy(for: "claude", serverURL: serverURL)
        XCTAssertEqual(command, "claude mcp add --transport http --scope user skwad http://localhost:9876")
    }

    func testOpencodeCopyCommandIsSimplified() {
        let command = MCPCommandView.mcpCommandCopy(for: "opencode", serverURL: serverURL)
        XCTAssertEqual(command, "opencode mcp add")
    }

    func testCopilotCopyCommandIsEmpty() {
        let command = MCPCommandView.mcpCommandCopy(for: "copilot", serverURL: serverURL)
        XCTAssertEqual(command, "")
    }

    func testCodexCopyMatchesDisplay() {
        let display = MCPCommandView.mcpCommand(for: "codex", serverURL: serverURL)
        let copy = MCPCommandView.mcpCommandCopy(for: "codex", serverURL: serverURL)
        XCTAssertEqual(copy, display)
    }

    func testGeminiCopyMatchesDisplay() {
        let display = MCPCommandView.mcpCommand(for: "gemini", serverURL: serverURL)
        let copy = MCPCommandView.mcpCommandCopy(for: "gemini", serverURL: serverURL)
        XCTAssertEqual(copy, display)
    }

    // MARK: - Server URL Substitution

    func testDifferentURLsAreSubstitutedCorrectly() {
        let url1 = "http://localhost:8080"
        let url2 = "http://192.168.1.100:9999"

        let cmd1 = MCPCommandView.mcpCommand(for: "codex", serverURL: url1)
        let cmd2 = MCPCommandView.mcpCommand(for: "codex", serverURL: url2)

        XCTAssertTrue(cmd1.contains("8080"))
        XCTAssertTrue(cmd2.contains("192.168.1.100"))
        XCTAssertTrue(cmd2.contains("9999"))
    }
}
