import Testing
import SwiftUI
@testable import Skwad

/// Tests for AgentManager that actually test the real implementation
/// These tests use @MainActor to work with the MainActor-isolated AgentManager
@Suite("AgentManager", .serialized)
@MainActor
struct AgentManagerTests {

    // MARK: - Test Setup

    /// Create a fresh AgentManager for testing
    /// Note: We need to avoid triggering saved agent loading
    static func createTestManager() -> AgentManager {
        // The manager checks for XCODE_RUNNING_FOR_PREVIEWS to skip loading
        // For tests, we'll create it and manually set up state
        let manager = AgentManager()
        // Clear any loaded state
        manager.agents = []
        manager.workspaces = []
        manager.currentWorkspaceId = nil
        return manager
    }

    /// Create test agents
    static func createTestAgents(count: Int) -> [Agent] {
        (0..<count).map { i in
            Agent(name: "Agent\(i)", folder: "/tmp/test/agent\(i)")
        }
    }

    /// Set up a manager with a workspace and agents
    static func setupManager(agentCount: Int, mode: LayoutMode = .single) -> AgentManager {
        let manager = createTestManager()
        let agents = createTestAgents(count: agentCount)

        manager.agents = agents
        let workspace = Workspace(
            name: "Test",
            agentIds: agents.map { $0.id },
            layoutMode: mode,
            activeAgentIds: agents.isEmpty ? [] : [agents[0].id],
            focusedPaneIndex: 0
        )
        manager.workspaces = [workspace]
        manager.currentWorkspaceId = workspace.id

        return manager
    }

    // MARK: - Workspace Tests

    @Suite("Workspace CRUD")
    struct WorkspaceCRUDTests {

        @Test("addWorkspace creates new workspace")
        func addWorkspaceCreatesNew() {
            let manager = AgentManagerTests.createTestManager()

            let workspace = manager.addWorkspace(name: "New Workspace", color: .blue)

            #expect(manager.workspaces.count == 1)
            #expect(manager.workspaces[0].name == "New Workspace")
            #expect(manager.currentWorkspaceId == workspace.id)
        }

        @Test("addWorkspace sets as current")
        func addWorkspaceSetsAsCurrent() {
            let manager = AgentManagerTests.createTestManager()

            let ws1 = manager.addWorkspace(name: "First")
            let ws2 = manager.addWorkspace(name: "Second")

            #expect(manager.currentWorkspaceId == ws2.id)
            #expect(manager.workspaces.count == 2)
            _ = ws1 // silence warning
        }

        @Test("updateWorkspace changes name and color")
        func updateWorkspaceChangesNameAndColor() {
            let manager = AgentManagerTests.createTestManager()
            let workspace = manager.addWorkspace(name: "Original", color: .blue)

            manager.updateWorkspace(id: workspace.id, name: "Updated", colorHex: WorkspaceColor.green.rawValue)

            #expect(manager.workspaces[0].name == "Updated")
            #expect(manager.workspaces[0].colorHex == WorkspaceColor.green.rawValue)
        }

        @Test("switchToWorkspace changes current workspace")
        func switchToWorkspaceChangesCurrent() {
            let manager = AgentManagerTests.createTestManager()
            let ws1 = manager.addWorkspace(name: "First")
            _ = manager.addWorkspace(name: "Second")

            manager.switchToWorkspace(ws1.id)

            #expect(manager.currentWorkspaceId == ws1.id)
        }

        @Test("switchToWorkspace ignores invalid id")
        func switchToWorkspaceIgnoresInvalid() {
            let manager = AgentManagerTests.createTestManager()
            _ = manager.addWorkspace(name: "First")
            let currentId = manager.currentWorkspaceId

            manager.switchToWorkspace(UUID())  // Invalid ID

            #expect(manager.currentWorkspaceId == currentId)
        }

        @Test("removeWorkspace removes and switches to another")
        func removeWorkspaceSwitchesToAnother() {
            let manager = AgentManagerTests.createTestManager()
            let ws1 = manager.addWorkspace(name: "First")
            let ws2 = manager.addWorkspace(name: "Second")

            manager.removeWorkspace(ws2)

            #expect(manager.workspaces.count == 1)
            #expect(manager.currentWorkspaceId == ws1.id)
        }

        @Test("moveWorkspace reorders workspaces")
        func moveWorkspaceReorders() {
            let manager = AgentManagerTests.createTestManager()
            _ = manager.addWorkspace(name: "First")
            _ = manager.addWorkspace(name: "Second")
            _ = manager.addWorkspace(name: "Third")

            manager.moveWorkspace(from: IndexSet(integer: 0), to: 2)

            #expect(manager.workspaces[0].name == "Second")
            #expect(manager.workspaces[1].name == "First")
        }
    }

    // MARK: - Agent CRUD Tests

    @Suite("Agent CRUD")
    struct AgentCRUDTests {

        @Test("addAgent creates agent and workspace if needed")
        func addAgentCreatesAgentAndWorkspace() {
            let manager = AgentManagerTests.createTestManager()

            manager.addAgent(folder: "/tmp/test", name: "TestAgent")

            #expect(manager.agents.count == 1)
            #expect(manager.agents[0].name == "TestAgent")
            #expect(manager.workspaces.count == 1)  // Default workspace created
            #expect(manager.currentWorkspaceAgents.count == 1)
        }

        @Test("addAgent uses folder name if no name provided")
        func addAgentUsesFolderName() {
            let manager = AgentManagerTests.createTestManager()

            manager.addAgent(folder: "/tmp/my-project")

            #expect(manager.agents[0].name == "my-project")
        }

        @Test("addAgent with insertAfterId inserts at correct position")
        func addAgentInsertsAtCorrectPosition() {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            let firstAgentId = manager.agents[0].id

            manager.addAgent(folder: "/tmp/new", name: "NewAgent", insertAfterId: firstAgentId)

            #expect(manager.agents.count == 3)
            #expect(manager.agents[1].name == "NewAgent")
        }

        @Test("updateAgent changes name and avatar")
        func updateAgentChangesNameAndAvatar() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.updateAgent(id: agentId, name: "Updated", avatar: "🚀")

            #expect(manager.agents[0].name == "Updated")
            #expect(manager.agents[0].avatar == "🚀")
        }

        @Test("duplicateAgent creates copy with suffix")
        func duplicateAgentCreatesCopy() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let original = manager.agents[0]

            manager.duplicateAgent(original)

            #expect(manager.agents.count == 2)
            #expect(manager.agents[1].name == "\(original.name) (copy)")
            #expect(manager.agents[1].folder == original.folder)
        }

        @Test("moveAgent reorders in workspace")
        func moveAgentReorders() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            manager.moveAgent(from: IndexSet(integer: 0), to: 2)

            let workspace = manager.currentWorkspace!
            #expect(workspace.agentIds[0] == manager.agents[1].id)
        }
    }

    // MARK: - Navigation Tests

    @Suite("Navigation")
    struct NavigationTests {

        @Test("selectNextAgent cycles forward")
        func selectNextAgentCyclesForward() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            #expect(manager.activeAgentIds == [agents[0].id])

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[1].id])

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectNextAgent wraps around")
        func selectNextAgentWrapsAround() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            // Go to last agent
            manager.activeAgentIds = [agents[2].id]

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[0].id])
        }

        @Test("selectPreviousAgent cycles backward")
        func selectPreviousAgentCyclesBackward() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            manager.selectPreviousAgent()
            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgent sets active in single mode")
        func selectAgentSetsActiveInSingleMode() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            manager.selectAgent(agents[2].id)

            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex selects correct agent")
        func selectAgentAtIndexSelectsCorrect() {
            let manager = AgentManagerTests.setupManager(agentCount: 4)
            let agents = manager.currentWorkspaceAgents

            manager.selectAgentAtIndex(2)

            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex ignores out of bounds")
        func selectAgentAtIndexIgnoresOutOfBounds() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let original = manager.activeAgentIds

            manager.selectAgentAtIndex(10)

            #expect(manager.activeAgentIds == original)
        }
    }

    // MARK: - Layout Tests

    @Suite("Layout")
    struct LayoutTests {

        @Test("enterSplit sets up two panes")
        func enterSplitSetsTwoPanes() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            manager.enterSplit(.splitVertical)

            #expect(manager.layoutMode == .splitVertical)
            #expect(manager.activeAgentIds.count == 2)
        }

        @Test("enterSplit requires at least 2 agents")
        func enterSplitRequiresTwoAgents() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)

            manager.enterSplit(.splitVertical)

            #expect(manager.layoutMode == .single)  // Should remain single
        }

        @Test("focusPane changes focused pane index")
        func focusPaneChangesFocusedIndex() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            manager.focusPane(1)

            #expect(manager.focusedPaneIndex == 1)
        }

        @Test("selectNextPane cycles through panes")
        func selectNextPaneCycles() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            #expect(manager.focusedPaneIndex == 0)

            manager.selectNextPane()
            #expect(manager.focusedPaneIndex == 1)

            manager.selectNextPane()
            #expect(manager.focusedPaneIndex == 0)  // Wraps
        }

        @Test("selectPreviousPane cycles backward")
        func selectPreviousPaneCycles() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            manager.selectPreviousPane()
            #expect(manager.focusedPaneIndex == 1)  // Wraps to last
        }

        @Test("paneIndex returns correct position")
        func paneIndexReturnsCorrectPosition() {
            let manager = AgentManagerTests.setupManager(agentCount: 4)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitVertical)

            #expect(manager.paneIndex(for: agents[0].id) == 0)
            #expect(manager.paneIndex(for: agents[1].id) == 1)
            #expect(manager.paneIndex(for: agents[2].id) == nil)  // Not in pane
        }

        @Test("splitRatio can be changed")
        func splitRatioCanBeChanged() {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            manager.enterSplit(.splitVertical)

            manager.splitRatio = 0.7

            #expect(manager.splitRatio == 0.7)
        }
    }

    // MARK: - Registration Tests

    @Suite("Registration")
    struct RegistrationTests {

        @Test("setRegistered updates agent state")
        func setRegisteredUpdatesState() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.setRegistered(for: agentId, registered: true)

            #expect(manager.agents[0].isRegistered == true)
            #expect(manager.isRegistered(agentId: agentId) == true)
        }

        @Test("isRegistered returns false for unregistered")
        func isRegisteredReturnsFalseForUnregistered() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            #expect(manager.isRegistered(agentId: agentId) == false)
        }

        @Test("isRegistered returns false for unknown agent")
        func isRegisteredReturnsFalseForUnknown() {
            let manager = AgentManagerTests.setupManager(agentCount: 1)

            #expect(manager.isRegistered(agentId: UUID()) == false)
        }
    }

    // MARK: - Status Tests

    @Suite("Status")
    struct StatusTests {

        @Test("isWorkspaceActive returns true if any agent is running")
        func isWorkspaceActiveReturnsTrueIfRunning() {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            manager.agents[0].status = .running

            let isActive = manager.isWorkspaceActive(manager.currentWorkspace!)

            #expect(isActive == true)
        }

        @Test("isWorkspaceActive returns false if all agents idle")
        func isWorkspaceActiveReturnsFalseIfAllIdle() {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            // Default status is .idle

            let isActive = manager.isWorkspaceActive(manager.currentWorkspace!)

            #expect(isActive == false)
        }
    }

    // MARK: - Derived State Tests

    @Suite("Derived State")
    struct DerivedStateTests {

        @Test("currentWorkspaceAgents returns agents in workspace order")
        func currentWorkspaceAgentsReturnsInOrder() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            let workspaceAgents = manager.currentWorkspaceAgents

            #expect(workspaceAgents.count == 3)
            #expect(workspaceAgents[0].id == manager.agents[0].id)
        }

        @Test("selectedAgent returns first active agent")
        func selectedAgentReturnsFirstActive() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            #expect(manager.selectedAgent?.id == manager.agents[0].id)
        }

        @Test("activeAgentId returns focused pane agent in split mode")
        func activeAgentIdReturnsFocusedInSplit() {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitVertical)

            manager.focusPane(1)

            #expect(manager.activeAgentId == agents[1].id)
        }
    }
}
