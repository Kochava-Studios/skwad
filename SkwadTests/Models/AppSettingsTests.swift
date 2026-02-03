import Testing
import SwiftUI
@testable import Skwad

@Suite("AppSettings")
struct AppSettingsTests {

    // MARK: - Color Hex Conversion

    @Suite("Color Hex Conversion")
    struct ColorHexConversionTests {

        @Test("parses 6-digit hex with hash")
        func parsesHexWithHash() {
            let color = Color(hex: "#FF0000")
            #expect(color != nil)
        }

        @Test("parses 6-digit hex without hash")
        func parsesHexWithoutHash() {
            let color = Color(hex: "FF0000")
            #expect(color != nil)
        }

        @Test("parses lowercase hex")
        func parsesLowercaseHex() {
            let color = Color(hex: "#ff0000")
            #expect(color != nil)
        }

        @Test("parses mixed case hex")
        func parsesMixedCaseHex() {
            let color = Color(hex: "#Ff00aB")
            #expect(color != nil)
        }

        @Test("parses short hex as padded value")
        func shortHexParsedAsPadded() {
            // #FF00 is parsed as 0xFF00 = 0x00FF00 (green)
            let color = Color(hex: "#FF00")
            #expect(color != nil)
        }

        @Test("returns nil for invalid hex - non-hex chars")
        func invalidHexNonHexChars() {
            let color = Color(hex: "#GGHHII")
            #expect(color == nil)
        }

        @Test("returns nil for empty string")
        func invalidHexEmpty() {
            let color = Color(hex: "")
            #expect(color == nil)
        }

        @Test("converts color to hex string")
        func colorToHex() {
            let color = Color(red: 1.0, green: 0.0, blue: 0.0)
            let hex = color.toHex()
            #expect(hex != nil)
            #expect(hex?.hasPrefix("#") == true)
            #expect(hex?.count == 7)
        }

        @Test("round-trips color through hex - red")
        func roundTripRed() {
            let original = Color(hex: "#FF0000")!
            let hex = original.toHex()!
            let restored = Color(hex: hex)
            #expect(restored != nil)
            // The restored hex should be the same
            #expect(restored?.toHex() == hex)
        }

        @Test("round-trips color through hex - green")
        func roundTripGreen() {
            let original = Color(hex: "#00FF00")!
            let hex = original.toHex()!
            let restored = Color(hex: hex)
            #expect(restored != nil)
        }

        @Test("round-trips color through hex - blue")
        func roundTripBlue() {
            let original = Color(hex: "#0000FF")!
            let hex = original.toHex()!
            let restored = Color(hex: hex)
            #expect(restored != nil)
        }

        @Test("handles whitespace in hex string")
        func handlesWhitespace() {
            let color = Color(hex: "  #FF0000  ")
            #expect(color != nil)
        }
    }

    // MARK: - Color Luminance

    @Suite("Color Luminance")
    struct ColorLuminanceTests {

        @Test("white is light")
        func whiteIsLight() {
            let white = Color(hex: "#FFFFFF")!
            #expect(white.isLight == true)
        }

        @Test("yellow is light")
        func yellowIsLight() {
            let yellow = Color(hex: "#FFFF00")!
            #expect(yellow.isLight == true)
        }

        @Test("light gray is light")
        func lightGrayIsLight() {
            let lightGray = Color(hex: "#CCCCCC")!
            #expect(lightGray.isLight == true)
        }

        @Test("black is dark")
        func blackIsDark() {
            let black = Color(hex: "#000000")!
            #expect(black.isLight == false)
        }

        @Test("navy is dark")
        func navyIsDark() {
            let navy = Color(hex: "#000080")!
            #expect(navy.isLight == false)
        }

        @Test("dark gray is dark")
        func darkGrayIsDark() {
            let darkGray = Color(hex: "#333333")!
            #expect(darkGray.isLight == false)
        }
    }

    // MARK: - Color Adjustment

    @Suite("Color Adjustment")
    struct ColorAdjustmentTests {

        @Test("darkened reduces brightness")
        func darkenedReducesBrightness() {
            let original = Color(hex: "#808080")!
            let darkened = original.darkened(by: 0.1)
            // The darkened color should have different hex
            #expect(darkened.toHex() != original.toHex())
        }

        @Test("lightened increases brightness")
        func lightenedIncreasesBrightness() {
            let original = Color(hex: "#808080")!
            let lightened = original.lightened(by: 0.1)
            // The lightened color should have different hex
            #expect(lightened.toHex() != original.toHex())
        }

        @Test("darkened clamps at black")
        func darkenedClampsAtBlack() {
            let black = Color(hex: "#000000")!
            let darkened = black.darkened(by: 1.0)
            // Should still be valid color (clamped to 0)
            #expect(darkened.toHex() != nil)
        }

        @Test("lightened clamps at white")
        func lightenedClampsAtWhite() {
            let white = Color(hex: "#FFFFFF")!
            let lightened = white.lightened(by: 1.0)
            // Should still be valid color (clamped to 1)
            #expect(lightened.toHex() != nil)
        }

        @Test("withAddedContrast darkens light colors")
        func contrastDarkensLight() {
            let lightColor = Color(hex: "#CCCCCC")!
            let contrasted = lightColor.withAddedContrast(by: 0.1)
            // Light colors get darkened
            #expect(contrasted.toHex() != lightColor.toHex())
        }

        @Test("withAddedContrast lightens dark colors")
        func contrastLightensDark() {
            let darkColor = Color(hex: "#333333")!
            let contrasted = darkColor.withAddedContrast(by: 0.1)
            // Dark colors get lightened
            #expect(contrasted.toHex() != darkColor.toHex())
        }
    }

    // MARK: - Command Resolution

    @Suite("Command Resolution")
    @MainActor
    struct CommandResolutionTests {

        @Test("predefined claude agent returns claude as command")
        func claudeAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "claude")
            #expect(command == "claude")
        }

        @Test("predefined codex agent returns codex as command")
        func codexAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "codex")
            #expect(command == "codex")
        }

        @Test("predefined aider agent returns aider as command")
        func aiderAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "aider")
            #expect(command == "aider")
        }

        @Test("predefined opencode agent returns opencode as command")
        func opencodeAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "opencode")
            #expect(command == "opencode")
        }

        @Test("predefined goose agent returns goose as command")
        func gooseAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "goose")
            #expect(command == "goose")
        }

        @Test("predefined gemini agent returns gemini as command")
        func geminiAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "gemini")
            #expect(command == "gemini")
        }

        @Test("unknown agent type returns type as command")
        func unknownAgentCommand() {
            let settings = AppSettings.shared
            let command = settings.getCommand(for: "unknownagent")
            #expect(command == "unknownagent")
        }

        @Test("getFullCommand combines command and options")
        func fullCommandCombinesCommandAndOptions() {
            let settings = AppSettings.shared
            // Save current value
            let originalOptions = settings.agentOptions_claude

            // Set options
            settings.agentOptions_claude = "--model opus"

            let fullCommand = settings.getFullCommand(for: "claude")
            #expect(fullCommand == "claude --model opus")

            // Restore
            settings.agentOptions_claude = originalOptions
        }

        @Test("getFullCommand with empty options returns just command")
        func fullCommandNoOptions() {
            let settings = AppSettings.shared
            // Save current value
            let originalOptions = settings.agentOptions_codex

            // Clear options
            settings.agentOptions_codex = ""

            let fullCommand = settings.getFullCommand(for: "codex")
            #expect(fullCommand == "codex")

            // Restore
            settings.agentOptions_codex = originalOptions
        }

        @Test("getOptions returns empty for unknown agent")
        func optionsForUnknownAgent() {
            let settings = AppSettings.shared
            let options = settings.getOptions(for: "unknownagent")
            #expect(options == "")
        }

        @Test("setOptions stores value for known agent type")
        func setOptionsForKnownAgent() {
            let settings = AppSettings.shared
            // Save current
            let original = settings.agentOptions_aider

            settings.setOptions("--test-option", for: "aider")
            #expect(settings.getOptions(for: "aider") == "--test-option")

            // Restore
            settings.agentOptions_aider = original
        }
    }

    // MARK: - Recent Repos

    @Suite("Recent Repos")
    @MainActor
    struct RecentReposTests {

        @Test("addRecentRepo adds to front")
        func addRecentRepoAddsToFront() {
            let settings = AppSettings.shared
            // Save current
            let original = settings.recentRepos

            settings.recentRepos = ["repo1", "repo2"]
            settings.addRecentRepo("repo3")

            #expect(settings.recentRepos.first == "repo3")

            // Restore
            settings.recentRepos = original
        }

        @Test("addRecentRepo deduplicates")
        func addRecentRepoDeduplicates() {
            let settings = AppSettings.shared
            let original = settings.recentRepos

            settings.recentRepos = ["repo1", "repo2", "repo3"]
            settings.addRecentRepo("repo2")

            // repo2 should now be first, and there should be no duplicate
            #expect(settings.recentRepos.first == "repo2")
            #expect(settings.recentRepos.filter { $0 == "repo2" }.count == 1)

            // Restore
            settings.recentRepos = original
        }

        @Test("addRecentRepo limits to 5")
        func addRecentRepoLimitsTo5() {
            let settings = AppSettings.shared
            let original = settings.recentRepos

            settings.recentRepos = ["repo1", "repo2", "repo3", "repo4", "repo5"]
            settings.addRecentRepo("repo6")

            #expect(settings.recentRepos.count == 5)
            #expect(settings.recentRepos.first == "repo6")
            #expect(!settings.recentRepos.contains("repo5"))

            // Restore
            settings.recentRepos = original
        }
    }

    // MARK: - Recent Agents

    @Suite("Recent Agents")
    @MainActor
    struct RecentAgentsTests {

        @Test("addRecentAgent deduplicates by folder")
        func addRecentAgentDeduplicatesByFolder() {
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
            #expect(settings.recentAgents.count == 2)
            // The updated agent should be first
            #expect(settings.recentAgents.first?.folder == "/path/to/folder1")

            // Restore
            settings.recentAgents = original
        }

        @Test("addRecentAgent limits to 8")
        func addRecentAgentLimitsTo8() {
            let settings = AppSettings.shared
            let original = settings.recentAgents

            settings.recentAgents = []

            // Add 9 agents
            for i in 1...9 {
                let agent = Agent(name: "Agent\(i)", folder: "/path/to/folder\(i)")
                settings.addRecentAgent(agent)
            }

            #expect(settings.recentAgents.count == 8)
            // Most recent should be first
            #expect(settings.recentAgents.first?.folder == "/path/to/folder9")
            // Oldest (folder1) should be gone
            #expect(!settings.recentAgents.contains { $0.folder == "/path/to/folder1" })

            // Restore
            settings.recentAgents = original
        }

        @Test("removeRecentAgent removes by folder")
        func removeRecentAgentByFolder() {
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

            #expect(settings.recentAgents.count == 1)
            #expect(settings.recentAgents.first?.folder == "/path/to/folder1")

            // Restore
            settings.recentAgents = original
        }
    }
}
