import Testing
import SwiftUI
@testable import Skwad

/// Tests for AgentManager that actually test the real implementation
@Suite("AgentManager", .serialized)
struct AgentManagerTests {

    // MARK: - Test Setup

    /// Create a fresh AgentManager for testing
    @MainActor
    static func createTestManager() -> AgentManager {
        let manager = AgentManager()
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
    @MainActor
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
        @MainActor
        func addWorkspaceCreatesNew() async {
            let manager = AgentManagerTests.createTestManager()

            let workspace = manager.addWorkspace(name: "New Workspace", color: .blue)

            #expect(manager.workspaces.count == 1)
            #expect(manager.workspaces[0].name == "New Workspace")
            #expect(manager.currentWorkspaceId == workspace.id)
        }

        @Test("addWorkspace sets as current")
        @MainActor
        func addWorkspaceSetsAsCurrent() async {
            let manager = AgentManagerTests.createTestManager()

            let ws1 = manager.addWorkspace(name: "First")
            let ws2 = manager.addWorkspace(name: "Second")

            #expect(manager.currentWorkspaceId == ws2.id)
            #expect(manager.workspaces.count == 2)
            _ = ws1
        }

        @Test("updateWorkspace changes name and color")
        @MainActor
        func updateWorkspaceChangesNameAndColor() async {
            let manager = AgentManagerTests.createTestManager()
            let workspace = manager.addWorkspace(name: "Original", color: .blue)

            manager.updateWorkspace(id: workspace.id, name: "Updated", colorHex: WorkspaceColor.green.rawValue)

            #expect(manager.workspaces[0].name == "Updated")
            #expect(manager.workspaces[0].colorHex == WorkspaceColor.green.rawValue)
        }

        @Test("switchToWorkspace changes current workspace")
        @MainActor
        func switchToWorkspaceChangesCurrent() async {
            let manager = AgentManagerTests.createTestManager()
            let ws1 = manager.addWorkspace(name: "First")
            _ = manager.addWorkspace(name: "Second")

            manager.switchToWorkspace(ws1.id)

            #expect(manager.currentWorkspaceId == ws1.id)
        }

        @Test("switchToWorkspace ignores invalid id")
        @MainActor
        func switchToWorkspaceIgnoresInvalid() async {
            let manager = AgentManagerTests.createTestManager()
            _ = manager.addWorkspace(name: "First")
            let currentId = manager.currentWorkspaceId

            manager.switchToWorkspace(UUID())

            #expect(manager.currentWorkspaceId == currentId)
        }

        @Test("removeWorkspace removes and switches to another")
        @MainActor
        func removeWorkspaceSwitchesToAnother() async {
            let manager = AgentManagerTests.createTestManager()
            let ws1 = manager.addWorkspace(name: "First")
            let ws2 = manager.addWorkspace(name: "Second")

            manager.removeWorkspace(ws2)

            #expect(manager.workspaces.count == 1)
            #expect(manager.currentWorkspaceId == ws1.id)
        }

        @Test("moveWorkspace reorders workspaces")
        @MainActor
        func moveWorkspaceReorders() async {
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
        @MainActor
        func addAgentCreatesAgentAndWorkspace() async {
            let manager = AgentManagerTests.createTestManager()

            manager.addAgent(folder: "/tmp/test", name: "TestAgent")

            #expect(manager.agents.count == 1)
            #expect(manager.agents[0].name == "TestAgent")
            #expect(manager.workspaces.count == 1)
            #expect(manager.currentWorkspaceAgents.count == 1)
        }

        @Test("addAgent uses folder name if no name provided")
        @MainActor
        func addAgentUsesFolderName() async {
            let manager = AgentManagerTests.createTestManager()

            manager.addAgent(folder: "/tmp/my-project")

            #expect(manager.agents[0].name == "my-project")
        }

        @Test("addAgent with insertAfterId inserts at correct position")
        @MainActor
        func addAgentInsertsAtCorrectPosition() async {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            let firstAgentId = manager.agents[0].id

            manager.addAgent(folder: "/tmp/new", name: "NewAgent", insertAfterId: firstAgentId)

            #expect(manager.agents.count == 3)
            #expect(manager.agents[1].name == "NewAgent")
        }

        @Test("updateAgent changes name and avatar")
        @MainActor
        func updateAgentChangesNameAndAvatar() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.updateAgent(id: agentId, name: "Updated", avatar: "🚀")

            #expect(manager.agents[0].name == "Updated")
            #expect(manager.agents[0].avatar == "🚀")
        }

        @Test("duplicateAgent creates copy with suffix")
        @MainActor
        func duplicateAgentCreatesCopy() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let original = manager.agents[0]

            manager.duplicateAgent(original)

            #expect(manager.agents.count == 2)
            #expect(manager.agents[1].name == "\(original.name) (copy)")
            #expect(manager.agents[1].folder == original.folder)
        }

        @Test("moveAgent reorders in workspace")
        @MainActor
        func moveAgentReorders() async {
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
        @MainActor
        func selectNextAgentCyclesForward() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            #expect(manager.activeAgentIds == [agents[0].id])

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[1].id])

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectNextAgent wraps around")
        @MainActor
        func selectNextAgentWrapsAround() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            manager.activeAgentIds = [agents[2].id]

            manager.selectNextAgent()
            #expect(manager.activeAgentIds == [agents[0].id])
        }

        @Test("selectPreviousAgent cycles backward")
        @MainActor
        func selectPreviousAgentCyclesBackward() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            manager.selectPreviousAgent()
            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgent sets active in single mode")
        @MainActor
        func selectAgentSetsActiveInSingleMode() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents

            manager.selectAgent(agents[2].id)

            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex selects correct agent")
        @MainActor
        func selectAgentAtIndexSelectsCorrect() async {
            let manager = AgentManagerTests.setupManager(agentCount: 4)
            let agents = manager.currentWorkspaceAgents

            manager.selectAgentAtIndex(2)

            #expect(manager.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex ignores out of bounds")
        @MainActor
        func selectAgentAtIndexIgnoresOutOfBounds() async {
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
        @MainActor
        func enterSplitSetsTwoPanes() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            manager.enterSplit(.splitVertical)

            #expect(manager.layoutMode == .splitVertical)
            #expect(manager.activeAgentIds.count == 2)
        }

        @Test("enterSplit requires at least 2 agents")
        @MainActor
        func enterSplitRequiresTwoAgents() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)

            manager.enterSplit(.splitVertical)

            #expect(manager.layoutMode == .single)
        }

        @Test("focusPane changes focused pane index")
        @MainActor
        func focusPaneChangesFocusedIndex() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            manager.focusPane(1)

            #expect(manager.focusedPaneIndex == 1)
        }

        @Test("selectNextPane cycles through panes")
        @MainActor
        func selectNextPaneCycles() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            #expect(manager.focusedPaneIndex == 0)

            manager.selectNextPane()
            #expect(manager.focusedPaneIndex == 1)

            manager.selectNextPane()
            #expect(manager.focusedPaneIndex == 0)
        }

        @Test("selectPreviousPane cycles backward")
        @MainActor
        func selectPreviousPaneCycles() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            manager.enterSplit(.splitVertical)

            manager.selectPreviousPane()
            #expect(manager.focusedPaneIndex == 1)
        }

        @Test("paneIndex returns correct position")
        @MainActor
        func paneIndexReturnsCorrectPosition() async {
            let manager = AgentManagerTests.setupManager(agentCount: 4)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitVertical)

            #expect(manager.paneIndex(for: agents[0].id) == 0)
            #expect(manager.paneIndex(for: agents[1].id) == 1)
            #expect(manager.paneIndex(for: agents[2].id) == nil)
        }

        @Test("splitRatio can be changed")
        @MainActor
        func splitRatioCanBeChanged() async {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            manager.enterSplit(.splitVertical)

            manager.splitRatio = 0.7

            #expect(manager.splitRatio == 0.7)
        }

        // MARK: - enterSplitWithNewAgent Tests

        @Test("enterSplitWithNewAgent from single creates dual vertical")
        @MainActor
        func enterSplitWithNewAgentFromSingleCreatesDualVertical() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let creatorId = manager.agents[0].id

            // Add a new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            #expect(manager.layoutMode == .splitVertical)
            #expect(manager.activeAgentIds.count == 2)
            #expect(manager.activeAgentIds[0] == creatorId)
            #expect(manager.activeAgentIds[1] == newAgentId)
            #expect(manager.focusedPaneIndex == 1)  // New agent gets focus
        }

        @Test("enterSplitWithNewAgent from dual vertical creates four pane")
        @MainActor
        func enterSplitWithNewAgentFromDualCreatesGrid() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitVertical)
            let creatorId = agents[0].id

            // Add a new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            #expect(manager.layoutMode == .gridFourPane)
            #expect(manager.activeAgentIds.count >= 3)
            #expect(manager.activeAgentIds.contains(newAgentId))
            // New agent should be focused
            let newAgentPane = manager.paneIndex(for: newAgentId)
            #expect(newAgentPane == manager.focusedPaneIndex)
        }

        @Test("enterSplitWithNewAgent from dual horizontal creates four pane")
        @MainActor
        func enterSplitWithNewAgentFromDualHorizontalCreatesGrid() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitHorizontal)
            let creatorId = agents[0].id

            // Add a new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            #expect(manager.layoutMode == .gridFourPane)
            #expect(manager.activeAgentIds.contains(newAgentId))
        }

        @Test("enterSplitWithNewAgent in four pane replaces pane 4 (index 3)")
        @MainActor
        func enterSplitWithNewAgentInGridReplacesPane4() async {
            let manager = AgentManagerTests.setupManager(agentCount: 5)
            let agents = manager.currentWorkspaceAgents

            // Set up four-pane with agents 0, 1, 2, 3
            manager.activeAgentIds = [agents[0].id, agents[1].id, agents[2].id, agents[3].id]
            manager.layoutMode = .gridFourPane
            let creatorId = agents[0].id  // Creator in pane 0

            // Add new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            #expect(manager.layoutMode == .gridFourPane)
            #expect(manager.activeAgentIds[3] == newAgentId)  // Replaced pane 4 (index 3)
            #expect(manager.activeAgentIds[0] == creatorId)  // Creator preserved
            #expect(manager.focusedPaneIndex == 3)
        }

        @Test("enterSplitWithNewAgent in four pane skips creator pane")
        @MainActor
        func enterSplitWithNewAgentInGridSkipsCreatorPane() async {
            let manager = AgentManagerTests.setupManager(agentCount: 5)
            let agents = manager.currentWorkspaceAgents

            // Set up four-pane with creator in pane 4 (index 3)
            manager.activeAgentIds = [agents[0].id, agents[1].id, agents[2].id, agents[3].id]
            manager.layoutMode = .gridFourPane
            let creatorId = agents[3].id  // Creator in pane 4

            // Add new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            #expect(manager.layoutMode == .gridFourPane)
            #expect(manager.activeAgentIds[3] == creatorId)  // Creator still in pane 4
            #expect(manager.activeAgentIds[2] == newAgentId)  // New agent in pane 3 (index 2)
            #expect(manager.focusedPaneIndex == 2)
        }

        @Test("enterSplitWithNewAgent replacement follows priority 4-3-2-1")
        @MainActor
        func enterSplitWithNewAgentFollowsReplacementPriority() async {
            let manager = AgentManagerTests.setupManager(agentCount: 5)
            let agents = manager.currentWorkspaceAgents

            // Set up four-pane with creator in pane 3 (index 2)
            manager.activeAgentIds = [agents[0].id, agents[1].id, agents[2].id, agents[3].id]
            manager.layoutMode = .gridFourPane
            let creatorId = agents[2].id  // Creator in pane 3

            // Add new agent
            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            // Should replace pane 4 first (index 3) since creator is in pane 3
            #expect(manager.activeAgentIds[3] == newAgentId)
            #expect(manager.activeAgentIds[2] == creatorId)  // Creator preserved
            #expect(manager.focusedPaneIndex == 3)
        }

        @Test("enterSplitWithNewAgent focuses new agent")
        @MainActor
        func enterSplitWithNewAgentFocusesNewAgent() async {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            let creatorId = manager.agents[0].id
            manager.focusedPaneIndex = 0

            let newAgentId = manager.addAgent(folder: "/tmp/new", name: "NewAgent")!

            manager.enterSplitWithNewAgent(newAgentId: newAgentId, creatorId: creatorId)

            // New agent should always be focused after split
            let newAgentPane = manager.paneIndex(for: newAgentId)
            #expect(newAgentPane == manager.focusedPaneIndex)
        }
    }

    // MARK: - Registration Tests

    @Suite("Registration")
    struct RegistrationTests {

        @Test("setRegistered updates agent state")
        @MainActor
        func setRegisteredUpdatesState() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.setRegistered(for: agentId, registered: true)

            #expect(manager.agents[0].isRegistered == true)
            #expect(manager.isRegistered(agentId: agentId) == true)
        }

        @Test("isRegistered returns false for unregistered")
        @MainActor
        func isRegisteredReturnsFalseForUnregistered() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            #expect(manager.isRegistered(agentId: agentId) == false)
        }

        @Test("isRegistered returns false for unknown agent")
        @MainActor
        func isRegisteredReturnsFalseForUnknown() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)

            #expect(manager.isRegistered(agentId: UUID()) == false)
        }
    }

    // MARK: - Status Tests

    @Suite("Status")
    struct StatusTests {

        @Test("isWorkspaceActive returns true if any agent is running")
        @MainActor
        func isWorkspaceActiveReturnsTrueIfRunning() async {
            let manager = AgentManagerTests.setupManager(agentCount: 2)
            manager.agents[0].status = .running

            let isActive = manager.isWorkspaceActive(manager.currentWorkspace!)

            #expect(isActive == true)
        }

        @Test("isWorkspaceActive returns false if all agents idle")
        @MainActor
        func isWorkspaceActiveReturnsFalseIfAllIdle() async {
            let manager = AgentManagerTests.setupManager(agentCount: 2)

            let isActive = manager.isWorkspaceActive(manager.currentWorkspace!)

            #expect(isActive == false)
        }
    }

    // MARK: - Derived State Tests

    @Suite("Derived State")
    struct DerivedStateTests {

        @Test("currentWorkspaceAgents returns agents in workspace order")
        @MainActor
        func currentWorkspaceAgentsReturnsInOrder() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            let workspaceAgents = manager.currentWorkspaceAgents

            #expect(workspaceAgents.count == 3)
            #expect(workspaceAgents[0].id == manager.agents[0].id)
        }

        @Test("selectedAgent returns first active agent")
        @MainActor
        func selectedAgentReturnsFirstActive() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)

            #expect(manager.selectedAgent?.id == manager.agents[0].id)
        }

        @Test("activeAgentId returns focused pane agent in split mode")
        @MainActor
        func activeAgentIdReturnsFocusedInSplit() async {
            let manager = AgentManagerTests.setupManager(agentCount: 3)
            let agents = manager.currentWorkspaceAgents
            manager.enterSplit(.splitVertical)

            manager.focusPane(1)

            #expect(manager.activeAgentId == agents[1].id)
        }
    }

    // MARK: - Markdown Panel Tests

    @Suite("Markdown Panel")
    struct MarkdownPanelTests {

        @Test("showMarkdownPanel sets file path")
        @MainActor
        func showMarkdownPanelSetsFilePath() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: agentId)

            #expect(manager.agents[0].markdownFilePath == "/tmp/test.md")
        }

        @Test("showMarkdownPanel adds to history")
        @MainActor
        func showMarkdownPanelAddsToHistory() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: agentId)

            #expect(manager.agents[0].markdownFileHistory.count == 1)
            #expect(manager.agents[0].markdownFileHistory[0] == "/tmp/test.md")
        }

        @Test("showMarkdownPanel maintains history order (most recent first)")
        @MainActor
        func showMarkdownPanelMaintainsHistoryOrder() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.showMarkdownPanel(filePath: "/tmp/first.md", forAgent: agentId)
            manager.showMarkdownPanel(filePath: "/tmp/second.md", forAgent: agentId)
            manager.showMarkdownPanel(filePath: "/tmp/third.md", forAgent: agentId)

            #expect(manager.agents[0].markdownFileHistory.count == 3)
            #expect(manager.agents[0].markdownFileHistory[0] == "/tmp/third.md")
            #expect(manager.agents[0].markdownFileHistory[1] == "/tmp/second.md")
            #expect(manager.agents[0].markdownFileHistory[2] == "/tmp/first.md")
        }

        @Test("showMarkdownPanel moves duplicate to front of history")
        @MainActor
        func showMarkdownPanelMovesDuplicateToFront() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.showMarkdownPanel(filePath: "/tmp/first.md", forAgent: agentId)
            manager.showMarkdownPanel(filePath: "/tmp/second.md", forAgent: agentId)
            manager.showMarkdownPanel(filePath: "/tmp/first.md", forAgent: agentId)

            #expect(manager.agents[0].markdownFileHistory.count == 2)
            #expect(manager.agents[0].markdownFileHistory[0] == "/tmp/first.md")
            #expect(manager.agents[0].markdownFileHistory[1] == "/tmp/second.md")
        }

        @Test("showMarkdownPanel ignores unknown agent")
        @MainActor
        func showMarkdownPanelIgnoresUnknownAgent() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)

            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: UUID())

            #expect(manager.agents[0].markdownFilePath == nil)
            #expect(manager.agents[0].markdownFileHistory.isEmpty)
        }

        @Test("closeMarkdownPanel clears file path")
        @MainActor
        func closeMarkdownPanelClearsFilePath() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id
            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: agentId)

            manager.closeMarkdownPanel(for: agentId)

            #expect(manager.agents[0].markdownFilePath == nil)
        }

        @Test("closeMarkdownPanel preserves history")
        @MainActor
        func closeMarkdownPanelPreservesHistory() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id
            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: agentId)

            manager.closeMarkdownPanel(for: agentId)

            #expect(manager.agents[0].markdownFileHistory.count == 1)
            #expect(manager.agents[0].markdownFileHistory[0] == "/tmp/test.md")
        }

        @Test("closeMarkdownPanel ignores unknown agent")
        @MainActor
        func closeMarkdownPanelIgnoresUnknownAgent() async {
            let manager = AgentManagerTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id
            manager.showMarkdownPanel(filePath: "/tmp/test.md", forAgent: agentId)

            manager.closeMarkdownPanel(for: UUID())

            #expect(manager.agents[0].markdownFilePath == "/tmp/test.md")
        }
    }
}
