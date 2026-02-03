import Foundation
@testable import Skwad

/// Mock implementation of AgentDataProvider for testing MCP services
/// Uses an actor for thread-safe state management
actor MockAgentDataProvider: AgentDataProvider {
    private var _agents: [Agent] = []
    private var _workspaces: [Workspace] = []
    private var _registeredAgentIds: Set<UUID> = []
    private var _injectedTexts: [(text: String, agentId: UUID)] = []
    private var _addedAgents: [(folder: String, name: String, avatar: String?, agentType: String)] = []

    // Public accessors for test assertions
    var registeredAgentIds: Set<UUID> {
        get { _registeredAgentIds }
    }

    var injectedTexts: [(text: String, agentId: UUID)] {
        get { _injectedTexts }
    }

    var addedAgents: [(folder: String, name: String, avatar: String?, agentType: String)] {
        get { _addedAgents }
    }

    init(agents: [Agent] = [], workspaces: [Workspace] = []) {
        self._agents = agents
        self._workspaces = workspaces
    }

    func getAgents() async -> [Agent] {
        return _agents
    }

    func getAgentsInSameWorkspace(as agentId: UUID) async -> [Agent] {
        // Find which workspace contains this agent
        guard let workspace = _workspaces.first(where: { $0.agentIds.contains(agentId) }) else {
            return []
        }

        // Return all agents in that workspace
        return workspace.agentIds.compactMap { id in
            _agents.first { $0.id == id }
        }
    }

    func setRegistered(for agentId: UUID, registered: Bool) async {
        if registered {
            _registeredAgentIds.insert(agentId)
        } else {
            _registeredAgentIds.remove(agentId)
        }

        // Also update the agent's isRegistered flag
        if let index = _agents.firstIndex(where: { $0.id == agentId }) {
            _agents[index].isRegistered = registered
        }
    }

    func injectText(_ text: String, for agentId: UUID) async {
        _injectedTexts.append((text: text, agentId: agentId))
    }

    func addAgent(folder: String, name: String, avatar: String?, agentType: String) async -> UUID? {
        _addedAgents.append((folder: folder, name: name, avatar: avatar, agentType: agentType))
        let newAgent = Agent(name: name, avatar: avatar, folder: folder, agentType: agentType)
        _agents.append(newAgent)
        return newAgent.id
    }

    // MARK: - Test Helpers

    /// Helper to check if an agent ID was registered during tests
    func containsRegisteredAgent(_ agentId: UUID) -> Bool {
        return _registeredAgentIds.contains(agentId)
    }

    /// Helper to manually register an agent for test setup
    func registerAgentForTest(_ agentId: UUID) {
        _registeredAgentIds.insert(agentId)
    }

    /// Create a test setup with agents in a workspace
    static func createTestSetup(agentCount: Int, workspaceName: String = "Test") -> (MockAgentDataProvider, Workspace) {
        var agents: [Agent] = []
        for i in 0..<agentCount {
            var agent = Agent(name: "Agent\(i)", folder: "/path/to/agent\(i)")
            agent.isRegistered = false
            agents.append(agent)
        }

        let workspace = Workspace(
            name: workspaceName,
            agentIds: agents.map { $0.id }
        )

        let provider = MockAgentDataProvider(agents: agents, workspaces: [workspace])
        return (provider, workspace)
    }

    /// Create test setup with registered agents
    static func createTestSetupWithRegistered(totalAgents: Int, registeredCount: Int) async -> (MockAgentDataProvider, Workspace, [Agent]) {
        var agents: [Agent] = []
        for i in 0..<totalAgents {
            var agent = Agent(name: "Agent\(i)", folder: "/path/to/agent\(i)")
            agent.isRegistered = i < registeredCount
            agents.append(agent)
        }

        let workspace = Workspace(
            name: "Test",
            agentIds: agents.map { $0.id }
        )

        let provider = MockAgentDataProvider(agents: agents, workspaces: [workspace])
        for i in 0..<registeredCount {
            await provider.registerAgentForTest(agents[i].id)
        }

        return (provider, workspace, agents)
    }
}
