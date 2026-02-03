import Testing
import SwiftUI
@testable import Skwad

/// Test helper that creates an AgentManager-like navigation structure for testing
/// without requiring MainActor isolation for the tests
struct NavigationTestHelper {
    var agents: [Agent]
    var workspaces: [Workspace]
    var currentWorkspaceId: UUID?

    init(agents: [Agent] = [], workspaces: [Workspace] = [], currentWorkspaceId: UUID? = nil) {
        self.agents = agents
        self.workspaces = workspaces
        self.currentWorkspaceId = currentWorkspaceId
    }

    var currentWorkspace: Workspace? {
        get {
            guard let id = currentWorkspaceId else { return nil }
            return workspaces.first { $0.id == id }
        }
        set {
            guard let workspace = newValue,
                  let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
            workspaces[index] = workspace
        }
    }

    var currentWorkspaceAgents: [Agent] {
        guard let workspace = currentWorkspace else { return [] }
        return workspace.agentIds.compactMap { id in agents.first { $0.id == id } }
    }

    var layoutMode: LayoutMode {
        get { currentWorkspace?.layoutMode ?? .single }
    }

    var activeAgentIds: [UUID] {
        get { currentWorkspace?.activeAgentIds ?? [] }
        set {
            guard let id = currentWorkspaceId,
                  let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
            workspaces[index].activeAgentIds = newValue
        }
    }

    var focusedPaneIndex: Int {
        get { currentWorkspace?.focusedPaneIndex ?? 0 }
        set {
            guard let id = currentWorkspaceId,
                  let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
            workspaces[index].focusedPaneIndex = newValue
        }
    }

    var activeAgentId: UUID? {
        guard focusedPaneIndex < activeAgentIds.count else { return activeAgentIds.first }
        return activeAgentIds[focusedPaneIndex]
    }

    func paneIndex(for agentId: UUID) -> Int? {
        activeAgentIds.firstIndex(of: agentId)
    }

    mutating func setLayoutMode(_ mode: LayoutMode) {
        guard let id = currentWorkspaceId,
              let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].layoutMode = mode
    }

    // MARK: - Navigation Methods (mirror AgentManager)

    mutating func selectNextAgent() {
        let workspaceAgents = currentWorkspaceAgents
        guard !workspaceAgents.isEmpty else { return }
        let currentId = activeAgentId
        guard let currentIndex = workspaceAgents.firstIndex(where: { $0.id == currentId }) else {
            activeAgentIds = [workspaceAgents[0].id]
            return
        }

        if layoutMode != .single {
            var next = (currentIndex + 1) % workspaceAgents.count
            while activeAgentIds.contains(workspaceAgents[next].id) && workspaceAgents[next].id != currentId {
                next = (next + 1) % workspaceAgents.count
            }
            activeAgentIds[focusedPaneIndex] = workspaceAgents[next].id
        } else {
            let nextIndex = (currentIndex + 1) % workspaceAgents.count
            activeAgentIds = [workspaceAgents[nextIndex].id]
        }
    }

    mutating func selectPreviousAgent() {
        let workspaceAgents = currentWorkspaceAgents
        guard !workspaceAgents.isEmpty else { return }
        let currentId = activeAgentId
        guard let currentIndex = workspaceAgents.firstIndex(where: { $0.id == currentId }) else {
            if let lastAgent = workspaceAgents.last {
                activeAgentIds = [lastAgent.id]
            }
            return
        }

        if layoutMode != .single {
            var prev = (currentIndex - 1 + workspaceAgents.count) % workspaceAgents.count
            while activeAgentIds.contains(workspaceAgents[prev].id) && workspaceAgents[prev].id != currentId {
                prev = (prev - 1 + workspaceAgents.count) % workspaceAgents.count
            }
            activeAgentIds[focusedPaneIndex] = workspaceAgents[prev].id
        } else {
            let previousIndex = (currentIndex - 1 + workspaceAgents.count) % workspaceAgents.count
            activeAgentIds = [workspaceAgents[previousIndex].id]
        }
    }

    mutating func selectAgentAtIndex(_ index: Int) {
        let workspaceAgents = currentWorkspaceAgents
        guard index >= 0 && index < workspaceAgents.count else { return }
        let agentId = workspaceAgents[index].id

        if layoutMode != .single {
            if let pane = paneIndex(for: agentId) {
                focusedPaneIndex = pane
            } else {
                activeAgentIds[focusedPaneIndex] = agentId
            }
        } else {
            activeAgentIds = [agentId]
        }
    }

    mutating func selectNextPane() {
        guard layoutMode != .single else { return }
        let paneCount = activeAgentIds.count
        focusedPaneIndex = (focusedPaneIndex + 1) % paneCount
    }

    mutating func selectPreviousPane() {
        guard layoutMode != .single else { return }
        let paneCount = activeAgentIds.count
        focusedPaneIndex = (focusedPaneIndex - 1 + paneCount) % paneCount
    }
}

@Suite("AgentManager Navigation")
struct AgentManagerNavigationTests {

    // MARK: - Test Helpers

    static func createTestAgents(count: Int) -> [Agent] {
        (0..<count).map { i in
            Agent(name: "Agent\(i)", folder: "/path/to/agent\(i)")
        }
    }

    static func createTestSetup(agentCount: Int, mode: LayoutMode = .single, activeCount: Int = 1) -> NavigationTestHelper {
        let agents = createTestAgents(count: agentCount)
        let activeIds = Array(agents.prefix(activeCount).map { $0.id })
        let workspace = Workspace(
            name: "Test",
            agentIds: agents.map { $0.id },
            layoutMode: mode,
            activeAgentIds: activeIds,
            focusedPaneIndex: 0
        )
        return NavigationTestHelper(
            agents: agents,
            workspaces: [workspace],
            currentWorkspaceId: workspace.id
        )
    }

    // MARK: - Single Mode Tests

    @Suite("Single Mode")
    struct SingleModeTests {

        @Test("selectNextAgent cycles forward")
        func selectNextAgentCyclesForward() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            // Start at first agent
            #expect(helper.activeAgentIds == [agents[0].id])

            // Move to next
            helper.selectNextAgent()
            #expect(helper.activeAgentIds == [agents[1].id])

            // Move to next
            helper.selectNextAgent()
            #expect(helper.activeAgentIds == [agents[2].id])
        }

        @Test("selectNextAgent wraps around")
        func selectNextAgentWrapsAround() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            // Go to last agent
            helper.activeAgentIds = [agents[2].id]

            // Next should wrap to first
            helper.selectNextAgent()
            #expect(helper.activeAgentIds == [agents[0].id])
        }

        @Test("selectPreviousAgent cycles backward")
        func selectPreviousAgentCyclesBackward() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            // Start at second agent
            helper.activeAgentIds = [agents[1].id]

            // Move back
            helper.selectPreviousAgent()
            #expect(helper.activeAgentIds == [agents[0].id])
        }

        @Test("selectPreviousAgent wraps around")
        func selectPreviousAgentWrapsAround() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            // Start at first agent
            #expect(helper.activeAgentIds == [agents[0].id])

            // Previous should wrap to last
            helper.selectPreviousAgent()
            #expect(helper.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex selects correct agent")
        func selectAgentAtIndexSelectsCorrect() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4)
            let agents = helper.currentWorkspaceAgents

            helper.selectAgentAtIndex(2)
            #expect(helper.activeAgentIds == [agents[2].id])
        }

        @Test("selectAgentAtIndex ignores out of bounds")
        func selectAgentAtIndexIgnoresOutOfBounds() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            // Try to select index 5 when only 3 agents exist
            helper.selectAgentAtIndex(5)
            #expect(helper.activeAgentIds == [agents[0].id])  // Should remain unchanged
        }

        @Test("selectAgentAtIndex ignores negative index")
        func selectAgentAtIndexIgnoresNegative() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agents = helper.currentWorkspaceAgents

            helper.selectAgentAtIndex(-1)
            #expect(helper.activeAgentIds == [agents[0].id])  // Should remain unchanged
        }

        @Test("navigation with single agent stays on same agent")
        func singleAgentNavigation() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 1)
            let agents = helper.currentWorkspaceAgents

            helper.selectNextAgent()
            #expect(helper.activeAgentIds == [agents[0].id])

            helper.selectPreviousAgent()
            #expect(helper.activeAgentIds == [agents[0].id])
        }
    }

    // MARK: - Split Mode Tests

    @Suite("Split Mode")
    struct SplitModeTests {

        @Test("selectNextPane cycles through panes")
        func selectNextPaneCycles() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)

            #expect(helper.focusedPaneIndex == 0)

            helper.selectNextPane()
            #expect(helper.focusedPaneIndex == 1)

            helper.selectNextPane()
            #expect(helper.focusedPaneIndex == 0)  // Wraps back
        }

        @Test("selectPreviousPane cycles backward")
        func selectPreviousPaneCycles() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)

            #expect(helper.focusedPaneIndex == 0)

            helper.selectPreviousPane()
            #expect(helper.focusedPaneIndex == 1)  // Wraps to last

            helper.selectPreviousPane()
            #expect(helper.focusedPaneIndex == 0)
        }

        @Test("selectNextAgent skips agents in other panes")
        func selectNextAgentSkipsOtherPanes() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4, mode: .splitVertical, activeCount: 2)
            let agents = helper.currentWorkspaceAgents

            // Agents 0 and 1 are in panes, focused on pane 0
            // selectNextAgent should go to agent 2 (skipping agent 1 which is in pane 1)
            helper.selectNextAgent()
            #expect(helper.activeAgentIds[0] == agents[2].id)
        }

        @Test("paneIndex returns correct position")
        func paneIndexReturnsCorrectPosition() {
            let helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4, mode: .splitVertical, activeCount: 2)
            let agents = helper.currentWorkspaceAgents

            #expect(helper.paneIndex(for: agents[0].id) == 0)
            #expect(helper.paneIndex(for: agents[1].id) == 1)
            #expect(helper.paneIndex(for: agents[2].id) == nil)  // Not in any pane
        }

        @Test("activeAgentId returns focused pane agent")
        func activeAgentIdReturnsFocusedPaneAgent() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)
            let agents = helper.currentWorkspaceAgents

            // Focus on pane 0
            helper.focusedPaneIndex = 0
            #expect(helper.activeAgentId == agents[0].id)

            // Focus on pane 1
            helper.focusedPaneIndex = 1
            #expect(helper.activeAgentId == agents[1].id)
        }

        @Test("selectNextPane does nothing in single mode")
        func selectNextPaneDoesNothingInSingleMode() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .single, activeCount: 1)

            helper.selectNextPane()
            #expect(helper.focusedPaneIndex == 0)
        }
    }

    // MARK: - Four Pane Grid Tests

    @Suite("Four Pane Grid")
    struct FourPaneGridTests {

        @Test("four pane mode tracks four active agents")
        func fourPaneModeTracksFourAgents() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)
            let agents = helper.currentWorkspaceAgents

            #expect(helper.activeAgentIds.count == 4)
            #expect(helper.activeAgentIds[0] == agents[0].id)
            #expect(helper.activeAgentIds[1] == agents[1].id)
            #expect(helper.activeAgentIds[2] == agents[2].id)
            #expect(helper.activeAgentIds[3] == agents[3].id)
        }

        @Test("selectNextPane cycles through four panes")
        func selectNextPaneCyclesFour() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)

            for expected in [1, 2, 3, 0] {
                helper.selectNextPane()
                #expect(helper.focusedPaneIndex == expected)
            }
        }

        @Test("selectAgentAtIndex focuses pane if agent is visible")
        func selectAgentAtIndexFocusesPane() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)

            // Select agent at index 2 (which is in pane 2)
            helper.selectAgentAtIndex(2)
            #expect(helper.focusedPaneIndex == 2)
        }

        @Test("selectAgentAtIndex replaces focused pane agent if not visible")
        func selectAgentAtIndexReplacesIfNotVisible() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)
            let agents = helper.currentWorkspaceAgents

            // Agent 4 is not in any pane
            helper.focusedPaneIndex = 1
            helper.selectAgentAtIndex(4)

            // Agent 4 should now be in pane 1
            #expect(helper.activeAgentIds[1] == agents[4].id)
        }
    }

    // MARK: - Agent Removal Tests

    @Suite("Agent Removal")
    struct AgentRemovalTests {

        @Test("removing agent updates workspace agentIds")
        func removingAgentUpdatesWorkspace() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agentToRemove = helper.agents[1]

            // Simulate removal
            helper.agents.removeAll { $0.id == agentToRemove.id }
            if let wsIndex = helper.workspaces.firstIndex(where: { $0.id == helper.currentWorkspaceId }) {
                helper.workspaces[wsIndex].agentIds.removeAll { $0 == agentToRemove.id }
            }

            #expect(helper.currentWorkspaceAgents.count == 2)
            #expect(!helper.currentWorkspaceAgents.contains { $0.id == agentToRemove.id })
        }

        @Test("removing active agent clears from activeAgentIds")
        func removingActiveAgentClearsActive() {
            var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
            let agentToRemove = helper.agents[0]  // The active agent

            // Simulate removal
            helper.agents.removeAll { $0.id == agentToRemove.id }
            if let wsIndex = helper.workspaces.firstIndex(where: { $0.id == helper.currentWorkspaceId }) {
                helper.workspaces[wsIndex].agentIds.removeAll { $0 == agentToRemove.id }
                helper.workspaces[wsIndex].activeAgentIds.removeAll { $0 == agentToRemove.id }
            }

            #expect(!helper.activeAgentIds.contains(agentToRemove.id))
        }
    }

    // MARK: - Empty Workspace Tests

    @Suite("Empty Workspace")
    struct EmptyWorkspaceTests {

        @Test("empty workspace returns empty agents")
        func emptyWorkspaceReturnsEmptyAgents() {
            let workspace = Workspace(name: "Empty")
            let helper = NavigationTestHelper(
                agents: [],
                workspaces: [workspace],
                currentWorkspaceId: workspace.id
            )

            #expect(helper.currentWorkspaceAgents.isEmpty)
        }

        @Test("selectNextAgent does nothing with no agents")
        func selectNextAgentDoesNothingWithNoAgents() {
            let workspace = Workspace(name: "Empty")
            var helper = NavigationTestHelper(
                agents: [],
                workspaces: [workspace],
                currentWorkspaceId: workspace.id
            )

            helper.selectNextAgent()
            #expect(helper.activeAgentIds.isEmpty)
        }

        @Test("selectPreviousAgent does nothing with no agents")
        func selectPreviousAgentDoesNothingWithNoAgents() {
            let workspace = Workspace(name: "Empty")
            var helper = NavigationTestHelper(
                agents: [],
                workspaces: [workspace],
                currentWorkspaceId: workspace.id
            )

            helper.selectPreviousAgent()
            #expect(helper.activeAgentIds.isEmpty)
        }
    }
}
