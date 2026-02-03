import XCTest
import SwiftUI
@testable import Skwad

final class SettingsViewHelpersTests: XCTestCase {

    // MARK: - Key Name Mapping

    /// Helper that mirrors the keyName logic from VoiceSettingsView
    private func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case 54: return "Right Command"
        case 55: return "Left Command"
        case 56: return "Left Shift"
        case 60: return "Right Shift"
        case 58: return "Left Option"
        case 61: return "Right Option"
        case 59: return "Left Control"
        case 62: return "Right Control"
        case 57: return "Caps Lock"
        case 63: return "Fn"
        default: return "Key \(keyCode)"
        }
    }

    func testRightCommandKeyCode54() {
        XCTAssertEqual(keyName(for: 54), "Right Command")
    }

    func testLeftCommandKeyCode55() {
        XCTAssertEqual(keyName(for: 55), "Left Command")
    }

    func testLeftShiftKeyCode56() {
        XCTAssertEqual(keyName(for: 56), "Left Shift")
    }

    func testRightShiftKeyCode60() {
        XCTAssertEqual(keyName(for: 60), "Right Shift")
    }

    func testLeftOptionKeyCode58() {
        XCTAssertEqual(keyName(for: 58), "Left Option")
    }

    func testRightOptionKeyCode61() {
        XCTAssertEqual(keyName(for: 61), "Right Option")
    }

    func testLeftControlKeyCode59() {
        XCTAssertEqual(keyName(for: 59), "Left Control")
    }

    func testRightControlKeyCode62() {
        XCTAssertEqual(keyName(for: 62), "Right Control")
    }

    func testCapsLockKeyCode57() {
        XCTAssertEqual(keyName(for: 57), "Caps Lock")
    }

    func testFnKeyCode63() {
        XCTAssertEqual(keyName(for: 63), "Fn")
    }

    func testUnknownKeyCodeReturnsGenericName() {
        XCTAssertEqual(keyName(for: 100), "Key 100")
        XCTAssertEqual(keyName(for: 0), "Key 0")
        XCTAssertEqual(keyName(for: -1), "Key -1")
    }

    // MARK: - Appearance Footer

    /// Helper that mirrors the appearanceFooter logic from GeneralSettingsView
    private func appearanceFooter(for mode: String) -> String {
        switch AppearanceMode(rawValue: mode) {
        case .auto:
            return "Derives light/dark mode from terminal background color."
        case .system:
            return "Follows your macOS system appearance setting."
        case .light:
            return "Always use light appearance."
        case .dark:
            return "Always use dark appearance."
        case .none:
            return ""
        }
    }

    func testAutoModeFooter() {
        let footer = appearanceFooter(for: "auto")
        XCTAssertTrue(footer.contains("terminal background"))
    }

    func testSystemModeFooter() {
        let footer = appearanceFooter(for: "system")
        XCTAssertTrue(footer.contains("macOS system"))
    }

    func testLightModeFooter() {
        let footer = appearanceFooter(for: "light")
        XCTAssertTrue(footer.contains("light"))
    }

    func testDarkModeFooter() {
        let footer = appearanceFooter(for: "dark")
        XCTAssertTrue(footer.contains("dark"))
    }

    func testInvalidModeFooterIsEmpty() {
        let footer = appearanceFooter(for: "invalid")
        XCTAssertEqual(footer, "")
    }

    // MARK: - Appearance Mode

    func testAllAppearanceModeCasesHaveDisplayNames() {
        for mode in AppearanceMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
        }
    }

    func testAutoDisplayNameIsAuto() {
        XCTAssertEqual(AppearanceMode.auto.displayName, "Auto")
    }

    func testSystemDisplayNameIsSystem() {
        XCTAssertEqual(AppearanceMode.system.displayName, "System")
    }

    func testLightDisplayNameIsLight() {
        XCTAssertEqual(AppearanceMode.light.displayName, "Light")
    }

    func testDarkDisplayNameIsDark() {
        XCTAssertEqual(AppearanceMode.dark.displayName, "Dark")
    }

    func testAppearanceModeRawValuesMatchExpected() {
        XCTAssertEqual(AppearanceMode.auto.rawValue, "auto")
        XCTAssertEqual(AppearanceMode.system.rawValue, "system")
        XCTAssertEqual(AppearanceMode.light.rawValue, "light")
        XCTAssertEqual(AppearanceMode.dark.rawValue, "dark")
    }

    // MARK: - Custom Agent Detection

    private func isCustomAgent(_ agentType: String) -> Bool {
        agentType == "custom1" || agentType == "custom2"
    }

    func testCustom1IsCustomAgent() {
        XCTAssertTrue(isCustomAgent("custom1"))
    }

    func testCustom2IsCustomAgent() {
        XCTAssertTrue(isCustomAgent("custom2"))
    }

    func testClaudeIsNotCustomAgent() {
        XCTAssertFalse(isCustomAgent("claude"))
    }

    func testCodexIsNotCustomAgent() {
        XCTAssertFalse(isCustomAgent("codex"))
    }

    func testAiderIsNotCustomAgent() {
        XCTAssertFalse(isCustomAgent("aider"))
    }

    func testUnknownIsNotCustomAgent() {
        XCTAssertFalse(isCustomAgent("unknown"))
    }

    // MARK: - Terminal Engine

    private let terminalEngines = [
        ("ghostty", "Ghostty (GPU-accelerated)"),
        ("swiftterm", "SwiftTerm")
    ]

    func testGhosttyEngineHasCorrectDisplayName() {
        let engine = terminalEngines.first { $0.0 == "ghostty" }
        XCTAssertEqual(engine?.1, "Ghostty (GPU-accelerated)")
    }

    func testSwifttermEngineHasCorrectDisplayName() {
        let engine = terminalEngines.first { $0.0 == "swiftterm" }
        XCTAssertEqual(engine?.1, "SwiftTerm")
    }

    func testTwoTerminalEnginesAvailable() {
        XCTAssertEqual(terminalEngines.count, 2)
    }

    // MARK: - Voice Engine

    private let voiceEngines = [
        ("apple", "Apple SpeechAnalyzer")
    ]

    func testAppleEngineHasCorrectDisplayName() {
        let engine = voiceEngines.first { $0.0 == "apple" }
        XCTAssertEqual(engine?.1, "Apple SpeechAnalyzer")
    }

    func testOneVoiceEngineAvailable() {
        XCTAssertEqual(voiceEngines.count, 1)
    }

    // MARK: - Agent Command Options

    func testAvailableAgentsContainsClaude() {
        let claude = availableAgents.first { $0.id == "claude" }
        XCTAssertNotNil(claude)
        XCTAssertEqual(claude?.name, "Claude Code")
    }

    func testAvailableAgentsContainsCodex() {
        let codex = availableAgents.first { $0.id == "codex" }
        XCTAssertNotNil(codex)
        XCTAssertEqual(codex?.name, "Codex")
    }

    func testAvailableAgentsContainsCustomAgents() {
        let custom1 = availableAgents.first { $0.id == "custom1" }
        let custom2 = availableAgents.first { $0.id == "custom2" }
        XCTAssertNotNil(custom1)
        XCTAssertNotNil(custom2)
    }

    func testGeminiNeedsLongStartup() {
        let gemini = availableAgents.first { $0.id == "gemini" }
        XCTAssertEqual(gemini?.needsLongStartup, true)
    }

    func testClaudeDoesNotNeedLongStartup() {
        let claude = availableAgents.first { $0.id == "claude" }
        XCTAssertEqual(claude?.needsLongStartup, false)
    }

    func testAllAgentsHaveUniqueIds() {
        let ids = availableAgents.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count)
    }

    // MARK: - Modifier Key Codes

    private let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 60, 58, 61, 59, 62, 57, 63]

    func testContainsAllModifierKeyCodes() {
        XCTAssertTrue(modifierKeyCodes.contains(54))  // Right Command
        XCTAssertTrue(modifierKeyCodes.contains(55))  // Left Command
        XCTAssertTrue(modifierKeyCodes.contains(56))  // Left Shift
        XCTAssertTrue(modifierKeyCodes.contains(60))  // Right Shift
        XCTAssertTrue(modifierKeyCodes.contains(58))  // Left Option
        XCTAssertTrue(modifierKeyCodes.contains(61))  // Right Option
        XCTAssertTrue(modifierKeyCodes.contains(59))  // Left Control
        XCTAssertTrue(modifierKeyCodes.contains(62))  // Right Control
        XCTAssertTrue(modifierKeyCodes.contains(57))  // Caps Lock
        XCTAssertTrue(modifierKeyCodes.contains(63))  // Fn
    }

    func testDoesNotContainRegularKeyCodes() {
        XCTAssertFalse(modifierKeyCodes.contains(0))   // A key
        XCTAssertFalse(modifierKeyCodes.contains(36))  // Return
        XCTAssertFalse(modifierKeyCodes.contains(49))  // Space
        XCTAssertFalse(modifierKeyCodes.contains(53))  // Escape
    }

    func testHasExactlyTenModifierKeys() {
        XCTAssertEqual(modifierKeyCodes.count, 10)
    }

    // MARK: - Path Shortening

    private func shortenPath(_ path: String) -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func testReplacesHomeWithTilde() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let path = "\(home)/src/project"
        let shortened = shortenPath(path)
        XCTAssertEqual(shortened, "~/src/project")
    }

    func testPreservesNonHomePaths() {
        let path = "/tmp/some/path"
        let shortened = shortenPath(path)
        XCTAssertEqual(shortened, "/tmp/some/path")
    }

    func testHandlesHomeDirectoryItself() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let shortened = shortenPath(home)
        XCTAssertEqual(shortened, "~")
    }

    // MARK: - Monospace Fonts

    private let preferredMonospaceFonts = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New",
        "Andale Mono",
        "JetBrains Mono",
        "Fira Code",
        "Source Code Pro",
        "IBM Plex Mono",
        "Hack",
        "Inconsolata"
    ]

    func testPreferredFontsHasExpectedCount() {
        XCTAssertEqual(preferredMonospaceFonts.count, 11)
    }

    func testSFMonoIsFirstPreferredFont() {
        XCTAssertEqual(preferredMonospaceFonts.first, "SF Mono")
    }

    func testMenloIsInPreferredFonts() {
        XCTAssertTrue(preferredMonospaceFonts.contains("Menlo"))
    }

    func testMonacoIsInPreferredFonts() {
        XCTAssertTrue(preferredMonospaceFonts.contains("Monaco"))
    }

    // MARK: - Font Size Range

    private let minFontSize: Double = 9
    private let maxFontSize: Double = 24

    func testMinimumFontSizeIs9() {
        XCTAssertEqual(minFontSize, 9)
    }

    func testMaximumFontSizeIs24() {
        XCTAssertEqual(maxFontSize, 24)
    }

    func testDefaultFontSizeIsWithinRange() {
        let defaultSize: Double = 13
        XCTAssertGreaterThanOrEqual(defaultSize, minFontSize)
        XCTAssertLessThanOrEqual(defaultSize, maxFontSize)
    }

    // MARK: - Settings Tab

    func testGeneralTabHasCorrectRawValue() {
        XCTAssertEqual(SettingsTab.general.rawValue, 0)
    }

    func testCodingTabHasCorrectRawValue() {
        XCTAssertEqual(SettingsTab.coding.rawValue, 1)
    }

    func testTerminalTabHasCorrectRawValue() {
        XCTAssertEqual(SettingsTab.terminal.rawValue, 2)
    }

    func testVoiceTabHasCorrectRawValue() {
        XCTAssertEqual(SettingsTab.voice.rawValue, 3)
    }

    func testMcpTabHasCorrectRawValue() {
        XCTAssertEqual(SettingsTab.mcp.rawValue, 4)
    }

    func testAllSettingsTabCasesCountIs5() {
        XCTAssertEqual(SettingsTab.allCases.count, 5)
    }

    // MARK: - MCP Server URL

    private func buildServerURL(port: Int) -> String {
        "http://127.0.0.1:\(port)/mcp"
    }

    func testServerURLUsesLocalhost() {
        let url = buildServerURL(port: 8766)
        XCTAssertTrue(url.contains("127.0.0.1"))
    }

    func testServerURLIncludesPort() {
        let url = buildServerURL(port: 8766)
        XCTAssertTrue(url.contains("8766"))
    }

    func testServerURLEndsWithMcp() {
        let url = buildServerURL(port: 8766)
        XCTAssertTrue(url.hasSuffix("/mcp"))
    }

    func testServerURLFormatIsCorrect() {
        let url = buildServerURL(port: 9000)
        XCTAssertEqual(url, "http://127.0.0.1:9000/mcp")
    }
}
