import XCTest
import SwiftUI
@testable import Skwad

final class SettingsViewHelpersTests: XCTestCase {

    // MARK: - Key Name Mapping (via ModifierKeyCode)

    func testRightCommandKeyCode54() {
        XCTAssertEqual(ModifierKeyCode.name(for: 54), "Right Command")
    }

    func testLeftCommandKeyCode55() {
        XCTAssertEqual(ModifierKeyCode.name(for: 55), "Left Command")
    }

    func testLeftShiftKeyCode56() {
        XCTAssertEqual(ModifierKeyCode.name(for: 56), "Left Shift")
    }

    func testRightShiftKeyCode60() {
        XCTAssertEqual(ModifierKeyCode.name(for: 60), "Right Shift")
    }

    func testLeftOptionKeyCode58() {
        XCTAssertEqual(ModifierKeyCode.name(for: 58), "Left Option")
    }

    func testRightOptionKeyCode61() {
        XCTAssertEqual(ModifierKeyCode.name(for: 61), "Right Option")
    }

    func testLeftControlKeyCode59() {
        XCTAssertEqual(ModifierKeyCode.name(for: 59), "Left Control")
    }

    func testRightControlKeyCode62() {
        XCTAssertEqual(ModifierKeyCode.name(for: 62), "Right Control")
    }

    func testCapsLockKeyCode57() {
        XCTAssertEqual(ModifierKeyCode.name(for: 57), "Caps Lock")
    }

    func testFnKeyCode63() {
        XCTAssertEqual(ModifierKeyCode.name(for: 63), "Fn")
    }

    func testUnknownKeyCodeReturnsGenericName() {
        XCTAssertEqual(ModifierKeyCode.name(for: 100), "Key 100")
        XCTAssertEqual(ModifierKeyCode.name(for: 0), "Key 0")
    }

    // MARK: - Appearance Footer (via AppearanceMode.footerDescription)

    func testAutoModeFooter() {
        XCTAssertTrue(AppearanceMode.auto.footerDescription.contains("terminal background"))
    }

    func testSystemModeFooter() {
        XCTAssertTrue(AppearanceMode.system.footerDescription.contains("macOS system"))
    }

    func testLightModeFooter() {
        XCTAssertTrue(AppearanceMode.light.footerDescription.contains("light"))
    }

    func testDarkModeFooter() {
        XCTAssertTrue(AppearanceMode.dark.footerDescription.contains("dark"))
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

    // MARK: - Agent Command Options (via availableAgents)

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

    // MARK: - Path Shortening (via PathUtils)

    func testReplacesHomeWithTilde() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let path = "\(home)/src/project"
        XCTAssertEqual(PathUtils.shortened(path), "~/src/project")
    }

    func testPreservesNonHomePaths() {
        XCTAssertEqual(PathUtils.shortened("/tmp/some/path"), "/tmp/some/path")
    }

    func testHandlesHomeDirectoryItself() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        XCTAssertEqual(PathUtils.shortened(home), "~")
    }

    // MARK: - MCP Server URL (via AppSettings)

    func testServerURLFormatIsCorrect() {
        XCTAssertEqual(AppSettings.shared.mcpServerURL, "http://127.0.0.1:\(AppSettings.shared.mcpServerPort)/mcp")
    }
}
