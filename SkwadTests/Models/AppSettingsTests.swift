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


    // MARK: - SavedAgent Companion Persistence

    func testSavedAgentCompanionRoundTrip() throws {
        let ownerId = UUID()
        let original = SavedAgent(id: UUID(), name: "Companion", avatar: "🤖", folder: "/tmp", createdBy: ownerId, isCompanion: true)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedAgent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.createdBy, ownerId)
        XCTAssertTrue(decoded.isCompanion)
    }

    func testSavedAgentNonCompanionRoundTrip() throws {
        let original = SavedAgent(id: UUID(), name: "Regular", avatar: "🤖", folder: "/tmp")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedAgent.self, from: data)

        XCTAssertNil(decoded.createdBy)
        XCTAssertFalse(decoded.isCompanion)
    }

    func testSavedAgentDecodesOldFormatWithoutCompanionFields() throws {
        // Simulate old SavedAgent JSON without createdBy/isCompanion
        let json = """
        {"id":"\(UUID().uuidString)","name":"Old","avatar":"🤖","folder":"/tmp","agentType":"claude"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SavedAgent.self, from: data)

        XCTAssertNil(decoded.createdBy)
        XCTAssertFalse(decoded.isCompanion)
    }


    // MARK: - Load Saved Agents (isPendingStart)

    @MainActor
    func testLoadSavedAgentsSetsIsPendingStartForShell() {
        let settings = AppSettings.shared
        let originalSaved = settings.savedAgents

        let shell = Agent(name: "MyShell", avatar: "🐚", folder: "/tmp/shell", agentType: "shell", shellCommand: "htop")
        settings.saveAgents([shell])

        let loaded = settings.loadSavedAgents()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertTrue(loaded[0].isPendingStart)

        // Restore
        settings.savedAgents = originalSaved
    }

    @MainActor
    func testLoadSavedAgentsDoesNotSetIsPendingStartForNonShell() {
        let settings = AppSettings.shared
        let originalSaved = settings.savedAgents

        let claude = Agent(name: "MyClaude", avatar: "🤖", folder: "/tmp/claude", agentType: "claude")
        settings.saveAgents([claude])

        let loaded = settings.loadSavedAgents()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertFalse(loaded[0].isPendingStart)

        // Restore
        settings.savedAgents = originalSaved
    }

    @MainActor
    func testLoadSavedAgentsMixedTypes() {
        let settings = AppSettings.shared
        let originalSaved = settings.savedAgents

        let claude = Agent(name: "Claude", avatar: "🤖", folder: "/tmp/claude", agentType: "claude")
        let shell = Agent(name: "Shell", avatar: "🐚", folder: "/tmp/shell", agentType: "shell", shellCommand: "top")
        let codex = Agent(name: "Codex", avatar: "📦", folder: "/tmp/codex", agentType: "codex")
        settings.saveAgents([claude, shell, codex])

        let loaded = settings.loadSavedAgents()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertFalse(loaded[0].isPendingStart)  // claude
        XCTAssertTrue(loaded[1].isPendingStart)    // shell
        XCTAssertFalse(loaded[2].isPendingStart)   // codex

        // Restore
        settings.savedAgents = originalSaved
    }

    // MARK: - Persona Persistence

    @MainActor
    func testPersonaCRUD() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        // Add
        let persona = settings.addPersona(name: "TDD Expert", instructions: "Follow TDD principles")
        XCTAssertEqual(settings.personas.count, originalPersonas.count + 1)
        XCTAssertEqual(settings.persona(for: persona.id)?.name, "TDD Expert")

        // Update
        settings.updatePersona(id: persona.id, name: "TDD Master", instructions: "Updated instructions")
        XCTAssertEqual(settings.persona(for: persona.id)?.name, "TDD Master")
        XCTAssertEqual(settings.persona(for: persona.id)?.instructions, "Updated instructions")

        // Remove
        settings.removePersona(persona)
        XCTAssertNil(settings.persona(for: persona.id))

        // Restore
        settings.personas = originalPersonas
    }

    func testPersonaNilLookup() {
        let settings = AppSettings.shared
        XCTAssertNil(settings.persona(for: nil))
        XCTAssertNil(settings.persona(for: UUID()))
    }

    func testSavedAgentPersonaIdRoundTrip() throws {
        let personaId = UUID()
        let original = SavedAgent(id: UUID(), name: "WithPersona", avatar: "🤖", folder: "/tmp", personaId: personaId)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SavedAgent.self, from: data)

        XCTAssertEqual(decoded.personaId, personaId)
    }

    func testSavedAgentDecodesOldFormatWithoutPersonaId() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Old","avatar":"🤖","folder":"/tmp","agentType":"claude"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SavedAgent.self, from: data)

        XCTAssertNil(decoded.personaId)
    }

    @MainActor
    func testSaveAndLoadAgentsPreservesPersonaId() {
        let settings = AppSettings.shared
        let originalSaved = settings.savedAgents

        let personaId = UUID()
        let agent = Agent(name: "WithPersona", avatar: "🤖", folder: "/tmp", agentType: "claude", personaId: personaId)
        settings.saveAgents([agent])

        let loaded = settings.loadSavedAgents()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].personaId, personaId)

        // Restore
        settings.savedAgents = originalSaved
    }

    // MARK: - Agent Persona Decoding

    func testAgentDecodesOldFormatWithoutPersonaId() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Old","folder":"/tmp","agentType":"claude"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertNil(decoded.personaId)
    }

    func testAgentPersonaIdRoundTrip() throws {
        let personaId = UUID()
        let original = Agent(name: "Test", folder: "/tmp", personaId: personaId)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Agent.self, from: data)

        XCTAssertEqual(decoded.personaId, personaId)
    }

    // MARK: - Persona Type & State

    func testNewPersonaDefaultsToUserEnabled() {
        let persona = Persona(name: "Test", instructions: "Do stuff")
        XCTAssertEqual(persona.type, .user)
        XCTAssertEqual(persona.state, .enabled)
    }

    func testPersonaDecodesOldFormatWithoutTypeAndState() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Old","instructions":"Do stuff"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Persona.self, from: data)

        XCTAssertEqual(decoded.type, .user)
        XCTAssertEqual(decoded.state, .enabled)
    }

    func testPersonaTypeAndStateRoundTrip() throws {
        let original = Persona(name: "System", instructions: "Do stuff", type: .system, state: .deleted)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Persona.self, from: data)

        XCTAssertEqual(decoded.type, .system)
        XCTAssertEqual(decoded.state, .deleted)
    }

    @MainActor
    func testRemoveUserPersonaHardDeletes() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        let persona = settings.addPersona(name: "UserPersona", instructions: "Test")
        XCTAssertEqual(persona.type, .user)

        settings.removePersona(persona)

        // Should be completely gone — not even in a deleted state
        XCTAssertNil(settings.persona(for: persona.id))

        settings.personas = originalPersonas
    }

    @MainActor
    func testRemoveSystemPersonaSoftDeletes() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        // Manually insert a system persona
        let systemPersona = Persona(id: UUID(), name: "SystemPersona", instructions: "System test", type: .system)
        var list = settings.personas
        list.append(systemPersona)
        settings.personas = list

        // Remove it
        settings.removePersona(systemPersona)

        // Should not appear in active personas
        XCTAssertNil(settings.persona(for: systemPersona.id))
        // But should not be hard-deleted (it's soft-deleted internally)
        XCTAssertFalse(settings.personas.contains { $0.id == systemPersona.id })

        settings.personas = originalPersonas
    }

    @MainActor
    func testInstallDefaultPersonasSkipsExisting() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        // Install once
        settings.installDefaultPersonas()
        let countAfterFirst = settings.personas.count

        // Install again — should be idempotent
        settings.installDefaultPersonas()
        XCTAssertEqual(settings.personas.count, countAfterFirst)

        settings.personas = originalPersonas
    }

    @MainActor
    func testInstallDefaultPersonasRespectsDeleted() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        // Install defaults
        settings.installDefaultPersonas()

        // Delete all system personas
        for persona in settings.personas where persona.type == .system {
            settings.removePersona(persona)
        }
        let countAfterDelete = settings.personas.count

        // Re-install — deleted ones should NOT reappear
        settings.installDefaultPersonas()
        XCTAssertEqual(settings.personas.count, countAfterDelete)

        settings.personas = originalPersonas
    }

    @MainActor
    func testRestoreDefaultPersonasResetsSystemPersonas() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        // Install defaults
        settings.installDefaultPersonas()

        // Edit a system persona
        if let system = settings.personas.first(where: { $0.type == .system }) {
            settings.updatePersona(id: system.id, name: "Modified", instructions: "Changed")
            XCTAssertEqual(settings.persona(for: system.id)?.name, "Modified")

            // Restore
            settings.restoreDefaultPersonas()

            // Should be back to original
            let restored = settings.persona(for: system.id)
            XCTAssertNotEqual(restored?.name, "Modified")
            XCTAssertNotEqual(restored?.instructions, "Changed")
        }

        settings.personas = originalPersonas
    }

    @MainActor
    func testRestoreDefaultPersonasReenablesDeleted() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        settings.installDefaultPersonas()

        // Delete a system persona
        if let system = settings.personas.first(where: { $0.type == .system }) {
            let systemId = system.id
            settings.removePersona(system)
            XCTAssertNil(settings.persona(for: systemId))

            // Restore brings it back
            settings.restoreDefaultPersonas()
            XCTAssertNotNil(settings.persona(for: systemId))
            XCTAssertEqual(settings.persona(for: systemId)?.state, .enabled)
        }

        settings.personas = originalPersonas
    }

    @MainActor
    func testRestoreDefaultPersonasKeepsUserPersonas() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        settings.installDefaultPersonas()
        let userPersona = settings.addPersona(name: "MyPersona", instructions: "Custom")

        settings.restoreDefaultPersonas()

        // User persona should still be there, untouched
        XCTAssertEqual(settings.persona(for: userPersona.id)?.name, "MyPersona")
        XCTAssertEqual(settings.persona(for: userPersona.id)?.instructions, "Custom")

        settings.personas = originalPersonas
    }

    @MainActor
    func testDeletedPersonasFilteredFromActiveList() {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        let persona = Persona(id: UUID(), name: "Deleted", instructions: "Gone", type: .system, state: .deleted)
        var list = settings.personas
        list.append(persona)
        settings.personas = list

        // Should not appear in the active list
        XCTAssertFalse(settings.personas.contains { $0.id == persona.id })

        settings.personas = originalPersonas
    }
}
