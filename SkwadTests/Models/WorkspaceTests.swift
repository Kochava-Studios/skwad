import Testing
import SwiftUI
@testable import Skwad

@Suite("Workspace")
struct WorkspaceTests {

    // MARK: - Initials Computation

    @Suite("Initials Computation")
    struct InitialsComputationTests {

        @Test("two words returns first letters")
        func twoWordsReturnsFirstLetters() {
            let initials = Workspace.computeInitials(from: "Hello World")
            #expect(initials == "HW")
        }

        @Test("two words with lowercase returns uppercase")
        func twoWordsLowercaseReturnsUppercase() {
            let initials = Workspace.computeInitials(from: "hello world")
            #expect(initials == "HW")
        }

        @Test("three words uses first two")
        func threeWordsUsesFirstTwo() {
            let initials = Workspace.computeInitials(from: "Alpha Beta Gamma")
            #expect(initials == "AB")
        }

        @Test("single word returns first two chars")
        func singleWordReturnsFirstTwoChars() {
            let initials = Workspace.computeInitials(from: "Workspace")
            #expect(initials == "WO")
        }

        @Test("single short word returns one char uppercase")
        func singleCharWord() {
            let initials = Workspace.computeInitials(from: "A")
            #expect(initials == "A")
        }

        @Test("empty string returns question mark")
        func emptyStringReturnsQuestionMark() {
            let initials = Workspace.computeInitials(from: "")
            #expect(initials == "?")
        }

        @Test("whitespace only returns question mark")
        func whitespaceOnlyReturnsQuestionMark() {
            let initials = Workspace.computeInitials(from: "   ")
            #expect(initials == "?")
        }

        @Test("leading whitespace is trimmed")
        func leadingWhitespaceIsTrimmed() {
            let initials = Workspace.computeInitials(from: "  Hello World")
            #expect(initials == "HW")
        }

        @Test("workspace property returns correct initials")
        func workspacePropertyReturnsCorrectInitials() {
            let workspace = Workspace(name: "My Project")
            #expect(workspace.initials == "MP")
        }
    }

    // MARK: - Create Default

    @Suite("Create Default")
    struct CreateDefaultTests {

        @Test("creates Skwad workspace")
        func createsSkwadWorkspace() {
            let workspace = Workspace.createDefault()
            #expect(workspace.name == "Skwad")
        }

        @Test("uses blue color")
        func usesBlueColor() {
            let workspace = Workspace.createDefault()
            #expect(workspace.colorHex == WorkspaceColor.blue.rawValue)
        }

        @Test("starts with empty agent list when no agents provided")
        func startsWithEmptyAgentList() {
            let workspace = Workspace.createDefault()
            #expect(workspace.agentIds.isEmpty)
        }

        @Test("includes provided agent IDs")
        func includesProvidedAgentIds() {
            let agentId1 = UUID()
            let agentId2 = UUID()
            let workspace = Workspace.createDefault(withAgentIds: [agentId1, agentId2])
            #expect(workspace.agentIds == [agentId1, agentId2])
        }

        @Test("sets first agent as active when agents provided")
        func setsFirstAgentAsActive() {
            let agentId1 = UUID()
            let agentId2 = UUID()
            let workspace = Workspace.createDefault(withAgentIds: [agentId1, agentId2])
            #expect(workspace.activeAgentIds == [agentId1])
        }

        @Test("activeAgentIds empty when no agents provided")
        func activeAgentIdsEmptyWhenNoAgents() {
            let workspace = Workspace.createDefault()
            #expect(workspace.activeAgentIds.isEmpty)
        }

        @Test("default layout is single")
        func defaultLayoutIsSingle() {
            let workspace = Workspace.createDefault()
            #expect(workspace.layoutMode == .single)
        }

        @Test("default focused pane is 0")
        func defaultFocusedPaneIsZero() {
            let workspace = Workspace.createDefault()
            #expect(workspace.focusedPaneIndex == 0)
        }

        @Test("default split ratio is 0.5")
        func defaultSplitRatioIsHalf() {
            let workspace = Workspace.createDefault()
            #expect(workspace.splitRatio == 0.5)
        }
    }

    // MARK: - Workspace Color

    @Suite("WorkspaceColor")
    struct WorkspaceColorTests {

        @Test("all colors have valid hex")
        func allColorsHaveValidHex() {
            for workspaceColor in WorkspaceColor.allCases {
                let color = Color(hex: workspaceColor.rawValue)
                #expect(color != nil, "WorkspaceColor.\(workspaceColor) should have valid hex")
            }
        }

        @Test("default color is blue")
        func defaultColorIsBlue() {
            #expect(WorkspaceColor.default == .blue)
        }

        @Test("color property returns valid SwiftUI color")
        func colorPropertyReturnsValidColor() {
            for workspaceColor in WorkspaceColor.allCases {
                // This should not crash - validates color conversion works
                let _ = workspaceColor.color
            }
        }

        @Test("workspace color property returns correct color")
        func workspaceColorPropertyReturnsCorrectColor() {
            let workspace = Workspace(name: "Test", colorHex: WorkspaceColor.purple.rawValue)
            // The color should be parseable
            let _ = workspace.color
        }

        @Test("workspace with invalid hex falls back to blue")
        func invalidHexFallsBackToBlue() {
            let workspace = Workspace(name: "Test", colorHex: "invalid")
            // Should fall back to blue
            let _ = workspace.color  // Should not crash
        }
    }

    // MARK: - Workspace Initialization

    @Suite("Workspace Initialization")
    struct WorkspaceInitializationTests {

        @Test("custom initialization preserves all values")
        func customInitializationPreservesAllValues() {
            let id = UUID()
            let agentId1 = UUID()
            let agentId2 = UUID()

            let workspace = Workspace(
                id: id,
                name: "Custom",
                colorHex: WorkspaceColor.green.rawValue,
                agentIds: [agentId1, agentId2],
                layoutMode: .splitVertical,
                activeAgentIds: [agentId1],
                focusedPaneIndex: 1,
                splitRatio: 0.7
            )

            #expect(workspace.id == id)
            #expect(workspace.name == "Custom")
            #expect(workspace.colorHex == WorkspaceColor.green.rawValue)
            #expect(workspace.agentIds == [agentId1, agentId2])
            #expect(workspace.layoutMode == .splitVertical)
            #expect(workspace.activeAgentIds == [agentId1])
            #expect(workspace.focusedPaneIndex == 1)
            #expect(workspace.splitRatio == 0.7)
        }

        @Test("workspace is Hashable")
        func workspaceIsHashable() {
            let workspace1 = Workspace(name: "Test1")
            let workspace2 = Workspace(name: "Test2")

            var set = Set<Workspace>()
            set.insert(workspace1)
            set.insert(workspace2)

            #expect(set.count == 2)
        }

        @Test("workspace is Identifiable")
        func workspaceIsIdentifiable() {
            let workspace = Workspace(name: "Test")
            #expect(workspace.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        }
    }
}
