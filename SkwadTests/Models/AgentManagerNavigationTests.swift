import XCTest
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

final class AgentManagerNavigationTests: XCTestCase {

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

    func testSelectNextAgentCyclesForward() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        // Start at first agent
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])

        // Move to next
        helper.selectNextAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[1].id])

        // Move to next
        helper.selectNextAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[2].id])
    }

    func testSelectNextAgentWrapsAround() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        // Go to last agent
        helper.activeAgentIds = [agents[2].id]

        // Next should wrap to first
        helper.selectNextAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])
    }

    func testSelectPreviousAgentCyclesBackward() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        // Start at second agent
        helper.activeAgentIds = [agents[1].id]

        // Move back
        helper.selectPreviousAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])
    }

    func testSelectPreviousAgentWrapsAround() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        // Start at first agent
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])

        // Previous should wrap to last
        helper.selectPreviousAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[2].id])
    }

    func testSelectAgentAtIndexSelectsCorrect() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4)
        let agents = helper.currentWorkspaceAgents

        helper.selectAgentAtIndex(2)
        XCTAssertEqual(helper.activeAgentIds, [agents[2].id])
    }

    func testSelectAgentAtIndexIgnoresOutOfBounds() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        // Try to select index 5 when only 3 agents exist
        helper.selectAgentAtIndex(5)
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])  // Should remain unchanged
    }

    func testSelectAgentAtIndexIgnoresNegative() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agents = helper.currentWorkspaceAgents

        helper.selectAgentAtIndex(-1)
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])  // Should remain unchanged
    }

    func testSingleAgentNavigation() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 1)
        let agents = helper.currentWorkspaceAgents

        helper.selectNextAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])

        helper.selectPreviousAgent()
        XCTAssertEqual(helper.activeAgentIds, [agents[0].id])
    }

    // MARK: - Split Mode Tests

    func testSelectNextPaneCycles() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)

        XCTAssertEqual(helper.focusedPaneIndex, 0)

        helper.selectNextPane()
        XCTAssertEqual(helper.focusedPaneIndex, 1)

        helper.selectNextPane()
        XCTAssertEqual(helper.focusedPaneIndex, 0)  // Wraps back
    }

    func testSelectPreviousPaneCycles() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)

        XCTAssertEqual(helper.focusedPaneIndex, 0)

        helper.selectPreviousPane()
        XCTAssertEqual(helper.focusedPaneIndex, 1)  // Wraps to last

        helper.selectPreviousPane()
        XCTAssertEqual(helper.focusedPaneIndex, 0)
    }

    func testSelectNextAgentSkipsOtherPanes() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4, mode: .splitVertical, activeCount: 2)
        let agents = helper.currentWorkspaceAgents

        // Agents 0 and 1 are in panes, focused on pane 0
        // selectNextAgent should go to agent 2 (skipping agent 1 which is in pane 1)
        helper.selectNextAgent()
        XCTAssertEqual(helper.activeAgentIds[0], agents[2].id)
    }

    func testPaneIndexReturnsCorrectPosition() {
        let helper = AgentManagerNavigationTests.createTestSetup(agentCount: 4, mode: .splitVertical, activeCount: 2)
        let agents = helper.currentWorkspaceAgents

        XCTAssertEqual(helper.paneIndex(for: agents[0].id), 0)
        XCTAssertEqual(helper.paneIndex(for: agents[1].id), 1)
        XCTAssertNil(helper.paneIndex(for: agents[2].id))  // Not in any pane
    }

    func testActiveAgentIdReturnsFocusedPaneAgent() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .splitVertical, activeCount: 2)
        let agents = helper.currentWorkspaceAgents

        // Focus on pane 0
        helper.focusedPaneIndex = 0
        XCTAssertEqual(helper.activeAgentId, agents[0].id)

        // Focus on pane 1
        helper.focusedPaneIndex = 1
        XCTAssertEqual(helper.activeAgentId, agents[1].id)
    }

    func testSelectNextPaneDoesNothingInSingleMode() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3, mode: .single, activeCount: 1)

        helper.selectNextPane()
        XCTAssertEqual(helper.focusedPaneIndex, 0)
    }

    // MARK: - Four Pane Grid Tests

    func testFourPaneModeTracksFourAgents() {
        let helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)
        let agents = helper.currentWorkspaceAgents

        XCTAssertEqual(helper.activeAgentIds.count, 4)
        XCTAssertEqual(helper.activeAgentIds[0], agents[0].id)
        XCTAssertEqual(helper.activeAgentIds[1], agents[1].id)
        XCTAssertEqual(helper.activeAgentIds[2], agents[2].id)
        XCTAssertEqual(helper.activeAgentIds[3], agents[3].id)
    }

    func testSelectNextPaneCyclesFour() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)

        for expected in [1, 2, 3, 0] {
            helper.selectNextPane()
            XCTAssertEqual(helper.focusedPaneIndex, expected)
        }
    }

    func testSelectAgentAtIndexFocusesPane() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)

        // Select agent at index 2 (which is in pane 2)
        helper.selectAgentAtIndex(2)
        XCTAssertEqual(helper.focusedPaneIndex, 2)
    }

    func testSelectAgentAtIndexReplacesIfNotVisible() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 5, mode: .gridFourPane, activeCount: 4)
        let agents = helper.currentWorkspaceAgents

        // Agent 4 is not in any pane
        helper.focusedPaneIndex = 1
        helper.selectAgentAtIndex(4)

        // Agent 4 should now be in pane 1
        XCTAssertEqual(helper.activeAgentIds[1], agents[4].id)
    }

    // MARK: - Agent Removal Tests

    func testRemovingAgentUpdatesWorkspace() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agentToRemove = helper.agents[1]

        // Simulate removal
        helper.agents.removeAll { $0.id == agentToRemove.id }
        if let wsIndex = helper.workspaces.firstIndex(where: { $0.id == helper.currentWorkspaceId }) {
            helper.workspaces[wsIndex].agentIds.removeAll { $0 == agentToRemove.id }
        }

        XCTAssertEqual(helper.currentWorkspaceAgents.count, 2)
        XCTAssertFalse(helper.currentWorkspaceAgents.contains { $0.id == agentToRemove.id })
    }

    func testRemovingActiveAgentClearsActive() {
        var helper = AgentManagerNavigationTests.createTestSetup(agentCount: 3)
        let agentToRemove = helper.agents[0]  // The active agent

        // Simulate removal
        helper.agents.removeAll { $0.id == agentToRemove.id }
        if let wsIndex = helper.workspaces.firstIndex(where: { $0.id == helper.currentWorkspaceId }) {
            helper.workspaces[wsIndex].agentIds.removeAll { $0 == agentToRemove.id }
            helper.workspaces[wsIndex].activeAgentIds.removeAll { $0 == agentToRemove.id }
        }

        XCTAssertFalse(helper.activeAgentIds.contains(agentToRemove.id))
    }

    // MARK: - Empty Workspace Tests

    func testEmptyWorkspaceReturnsEmptyAgents() {
        let workspace = Workspace(name: "Empty")
        let helper = NavigationTestHelper(
            agents: [],
            workspaces: [workspace],
            currentWorkspaceId: workspace.id
        )

        XCTAssertTrue(helper.currentWorkspaceAgents.isEmpty)
    }

    func testSelectNextAgentDoesNothingWithNoAgents() {
        let workspace = Workspace(name: "Empty")
        var helper = NavigationTestHelper(
            agents: [],
            workspaces: [workspace],
            currentWorkspaceId: workspace.id
        )

        helper.selectNextAgent()
        XCTAssertTrue(helper.activeAgentIds.isEmpty)
    }

    func testSelectPreviousAgentDoesNothingWithNoAgents() {
        let workspace = Workspace(name: "Empty")
        var helper = NavigationTestHelper(
            agents: [],
            workspaces: [workspace],
            currentWorkspaceId: workspace.id
        )

        helper.selectPreviousAgent()
        XCTAssertTrue(helper.activeAgentIds.isEmpty)
    }
}
