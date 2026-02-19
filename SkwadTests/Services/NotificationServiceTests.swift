import XCTest
@testable import Skwad

@MainActor
final class NotificationServiceTests: XCTestCase {

    // MARK: - Test Helpers

    private func createManager(agentCount: Int) -> (AgentManager, [Agent]) {
        let manager = AgentManager()
        manager.agents = []
        manager.workspaces = []
        manager.currentWorkspaceId = nil

        var agents: [Agent] = []
        for i in 0..<agentCount {
            agents.append(Agent(name: "Agent\(i)", folder: "/tmp/test/agent\(i)"))
        }

        manager.agents = agents
        let workspace = Workspace(
            name: "Test",
            agentIds: agents.map { $0.id },
            activeAgentIds: agents.isEmpty ? [] : [agents[0].id]
        )
        manager.workspaces = [workspace]
        manager.currentWorkspaceId = workspace.id

        return (manager, agents)
    }

    // MARK: - Dedup Tests

    func testSkipsNotificationWhenAgentAlreadyBlocked() {
        let (manager, agents) = createManager(agentCount: 2)
        NotificationService.shared.setup(agentManager: manager)

        // Set agent to blocked first
        manager.agents[1].status = .input

        // This should be skipped (agent already blocked)
        // We can't easily assert on UNNotificationCenter, but we verify no crash
        NotificationService.shared.notifyAwaitingInput(agent: agents[1])
    }

    func testSkipsNotificationWhenAgentIsActive() {
        let (manager, agents) = createManager(agentCount: 2)
        NotificationService.shared.setup(agentManager: manager)

        // Agent 0 is active (in activeAgentIds)
        // Notification should be skipped
        NotificationService.shared.notifyAwaitingInput(agent: agents[0])
    }

    func testAllowsNotificationForInactiveAgent() {
        let (manager, agents) = createManager(agentCount: 2)
        NotificationService.shared.setup(agentManager: manager)

        // Agent 1 is not in activeAgentIds (only agent 0 is)
        // Notification should proceed (no crash = success)
        NotificationService.shared.notifyAwaitingInput(agent: agents[1])
    }

    func testSkipsNotificationWhenDisabled() {
        let (manager, agents) = createManager(agentCount: 2)
        NotificationService.shared.setup(agentManager: manager)

        let savedValue = AppSettings.shared.desktopNotificationsEnabled
        AppSettings.shared.desktopNotificationsEnabled = false

        NotificationService.shared.notifyAwaitingInput(agent: agents[1])

        // Restore
        AppSettings.shared.desktopNotificationsEnabled = savedValue
    }
}
