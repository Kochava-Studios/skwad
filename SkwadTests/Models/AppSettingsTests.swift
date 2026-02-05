import XCTest
import SwiftUI
@testable import Skwad

final class AppSettingsTests: XCTestCase {

    // MARK: - Color Hex Conversion

    func testParsesHexWithHash() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testParsesHexWithoutHash() {
        let color = Color(hex: "FF0000")
        XCTAssertNotNil(color)
    }

    func testParsesLowercaseHex() {
        let color = Color(hex: "#ff0000")
        XCTAssertNotNil(color)
    }

    func testParsesMixedCaseHex() {
        let color = Color(hex: "#Ff00aB")
        XCTAssertNotNil(color)
    }

    func testShortHexParsedAsPadded() {
        // #FF00 is parsed as 0xFF00 = 0x00FF00 (green)
        let color = Color(hex: "#FF00")
        XCTAssertNotNil(color)
    }

    func testInvalidHexNonHexCharsReturnsNil() {
        let color = Color(hex: "#GGHHII")
        XCTAssertNil(color)
    }

    func testInvalidHexEmptyReturnsNil() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testColorToHex() {
        let color = Color(red: 1.0, green: 0.0, blue: 0.0)
        let hex = color.toHex()
        XCTAssertNotNil(hex)
        XCTAssertTrue(hex?.hasPrefix("#") == true)
        XCTAssertEqual(hex?.count, 7)
    }

    func testRoundTripRed() {
        let original = Color(hex: "#FF0000")!
        let hex = original.toHex()!
        let restored = Color(hex: hex)
        XCTAssertNotNil(restored)
        // The restored hex should be the same
        XCTAssertEqual(restored?.toHex(), hex)
    }

    func testRoundTripGreen() {
        let original = Color(hex: "#00FF00")!
        let hex = original.toHex()!
        let restored = Color(hex: hex)
        XCTAssertNotNil(restored)
    }

    func testRoundTripBlue() {
        let original = Color(hex: "#0000FF")!
        let hex = original.toHex()!
        let restored = Color(hex: hex)
        XCTAssertNotNil(restored)
    }

    func testHandlesWhitespaceInHexString() {
        let color = Color(hex: "  #FF0000  ")
        XCTAssertNotNil(color)
    }

    // MARK: - Color Luminance

    func testWhiteIsLight() {
        let white = Color(hex: "#FFFFFF")!
        XCTAssertTrue(white.isLight)
    }

    func testYellowIsLight() {
        let yellow = Color(hex: "#FFFF00")!
        XCTAssertTrue(yellow.isLight)
    }

    func testLightGrayIsLight() {
        let lightGray = Color(hex: "#CCCCCC")!
        XCTAssertTrue(lightGray.isLight)
    }

    func testBlackIsDark() {
        let black = Color(hex: "#000000")!
        XCTAssertFalse(black.isLight)
    }

    func testNavyIsDark() {
        let navy = Color(hex: "#000080")!
        XCTAssertFalse(navy.isLight)
    }

    func testDarkGrayIsDark() {
        let darkGray = Color(hex: "#333333")!
        XCTAssertFalse(darkGray.isLight)
    }

    // MARK: - Color Adjustment

    func testDarkenedReducesBrightness() {
        let original = Color(hex: "#808080")!
        let darkened = original.darkened(by: 0.1)
        // The darkened color should have different hex
        XCTAssertNotEqual(darkened.toHex(), original.toHex())
    }

    func testLightenedIncreasesBrightness() {
        let original = Color(hex: "#808080")!
        let lightened = original.lightened(by: 0.1)
        // The lightened color should have different hex
        XCTAssertNotEqual(lightened.toHex(), original.toHex())
    }

    func testDarkenedClampsAtBlack() {
        let black = Color(hex: "#000000")!
        let darkened = black.darkened(by: 1.0)
        // Should still be valid color (clamped to 0)
        XCTAssertNotNil(darkened.toHex())
    }

    func testLightenedClampsAtWhite() {
        let white = Color(hex: "#FFFFFF")!
        let lightened = white.lightened(by: 1.0)
        // Should still be valid color (clamped to 1)
        XCTAssertNotNil(lightened.toHex())
    }

    func testContrastDarkensLightColors() {
        let lightColor = Color(hex: "#CCCCCC")!
        let contrasted = lightColor.withAddedContrast(by: 0.1)
        // Light colors get darkened
        XCTAssertNotEqual(contrasted.toHex(), lightColor.toHex())
    }

    func testContrastLightensDarkColors() {
        let darkColor = Color(hex: "#333333")!
        let contrasted = darkColor.withAddedContrast(by: 0.1)
        // Dark colors get lightened
        XCTAssertNotEqual(contrasted.toHex(), darkColor.toHex())
    }

    // MARK: - Command Resolution

    @MainActor
    func testClaudeAgentCommand() {
        let settings = AppSettings.shared
        let command = settings.getCommand(for: "claude")
        XCTAssertEqual(command, "claude")
    }

    @MainActor
    func testCodexAgentCommand() {
        let settings = AppSettings.shared
        let command = settings.getCommand(for: "codex")
        XCTAssertEqual(command, "codex")
    }

    @MainActor
    func testOpencodeAgentCommand() {
        let settings = AppSettings.shared
        let command = settings.getCommand(for: "opencode")
        XCTAssertEqual(command, "opencode")
    }

    @MainActor
    func testGeminiAgentCommand() {
        let settings = AppSettings.shared
        let command = settings.getCommand(for: "gemini")
        XCTAssertEqual(command, "gemini")
    }

    @MainActor
    func testUnknownAgentCommand() {
        let settings = AppSettings.shared
        let command = settings.getCommand(for: "unknownagent")
        XCTAssertEqual(command, "unknownagent")
    }

    @MainActor
    func testFullCommandCombinesCommandAndOptions() {
        let settings = AppSettings.shared
        // Save current value
        let originalOptions = settings.agentOptions_claude

        // Set options
        settings.agentOptions_claude = "--model opus"

        let fullCommand = settings.getFullCommand(for: "claude")
        XCTAssertEqual(fullCommand, "claude --model opus")

        // Restore
        settings.agentOptions_claude = originalOptions
    }

    @MainActor
    func testFullCommandNoOptions() {
        let settings = AppSettings.shared
        // Save current value
        let originalOptions = settings.agentOptions_codex

        // Clear options
        settings.agentOptions_codex = ""

        let fullCommand = settings.getFullCommand(for: "codex")
        XCTAssertEqual(fullCommand, "codex")

        // Restore
        settings.agentOptions_codex = originalOptions
    }

    @MainActor
    func testOptionsForUnknownAgent() {
        let settings = AppSettings.shared
        let options = settings.getOptions(for: "unknownagent")
        XCTAssertEqual(options, "")
    }

    // MARK: - Recent Repos

    @MainActor
    func testAddRecentRepoAddsToFront() {
        let settings = AppSettings.shared
        // Save current
        let original = settings.recentRepos

        settings.recentRepos = ["repo1", "repo2"]
        settings.addRecentRepo("repo3")

        XCTAssertEqual(settings.recentRepos.first, "repo3")

        // Restore
        settings.recentRepos = original
    }

    @MainActor
    func testAddRecentRepoDeduplicates() {
        let settings = AppSettings.shared
        let original = settings.recentRepos

        settings.recentRepos = ["repo1", "repo2", "repo3"]
        settings.addRecentRepo("repo2")

        // repo2 should now be first, and there should be no duplicate
        XCTAssertEqual(settings.recentRepos.first, "repo2")
        XCTAssertEqual(settings.recentRepos.filter { $0 == "repo2" }.count, 1)

        // Restore
        settings.recentRepos = original
    }

    @MainActor
    func testAddRecentRepoLimitsTo5() {
        let settings = AppSettings.shared
        let original = settings.recentRepos

        settings.recentRepos = ["repo1", "repo2", "repo3", "repo4", "repo5"]
        settings.addRecentRepo("repo6")

        XCTAssertEqual(settings.recentRepos.count, 5)
        XCTAssertEqual(settings.recentRepos.first, "repo6")
        XCTAssertFalse(settings.recentRepos.contains("repo5"))

        // Restore
        settings.recentRepos = original
    }

    // MARK: - Recent Agents

    @MainActor
    func testAddRecentAgentDeduplicatesByFolder() {
        let settings = AppSettings.shared
        let original = settings.recentAgents

        // Create test agents
        let agent1 = Agent(name: "Agent1", folder: "/path/to/folder1")
        let agent2 = Agent(name: "Agent2", folder: "/path/to/folder2")
        let agent1Updated = Agent(name: "Agent1Updated", folder: "/path/to/folder1")

        settings.recentAgents = []
        settings.addRecentAgent(agent1)
        settings.addRecentAgent(agent2)
        settings.addRecentAgent(agent1Updated)

        // Should only have 2 entries (folder1 was deduplicated)
        XCTAssertEqual(settings.recentAgents.count, 2)
        // The updated agent should be first
        XCTAssertEqual(settings.recentAgents.first?.folder, "/path/to/folder1")

        // Restore
        settings.recentAgents = original
    }

    @MainActor
    func testAddRecentAgentLimitsTo8() {
        let settings = AppSettings.shared
        let original = settings.recentAgents

        settings.recentAgents = []

        // Add 9 agents
        for i in 1...9 {
            let agent = Agent(name: "Agent\(i)", folder: "/path/to/folder\(i)")
            settings.addRecentAgent(agent)
        }

        XCTAssertEqual(settings.recentAgents.count, 8)
        // Most recent should be first
        XCTAssertEqual(settings.recentAgents.first?.folder, "/path/to/folder9")
        // Oldest (folder1) should be gone
        XCTAssertFalse(settings.recentAgents.contains { $0.folder == "/path/to/folder1" })

        // Restore
        settings.recentAgents = original
    }

    @MainActor
    func testRemoveRecentAgentByFolder() {
        let settings = AppSettings.shared
        let original = settings.recentAgents

        // Setup
        settings.recentAgents = []
        let agent1 = Agent(name: "Agent1", folder: "/path/to/folder1")
        let agent2 = Agent(name: "Agent2", folder: "/path/to/folder2")
        settings.addRecentAgent(agent1)
        settings.addRecentAgent(agent2)

        // Create a SavedAgent to remove
        let savedToRemove = SavedAgent(id: UUID(), name: "Agent2", avatar: "🤖", folder: "/path/to/folder2")
        settings.removeRecentAgent(savedToRemove)

        XCTAssertEqual(settings.recentAgents.count, 1)
        XCTAssertEqual(settings.recentAgents.first?.folder, "/path/to/folder1")

        // Restore
        settings.recentAgents = original
    }
}
