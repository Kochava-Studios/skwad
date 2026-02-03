import Testing
import Foundation
@testable import Skwad

@Suite("MCPService", .serialized)
struct MCPServiceTests {

    // Note: MCPService.shared is a singleton, so tests must run serially
    // to avoid race conditions when setting the provider

    // MARK: - Test Helpers

    /// Create a fresh MCPService instance for testing
    /// Note: In production, MCPService.shared is used, but for testing we work with
    /// the provider directly when possible
    static func createTestService() async -> MCPService {
        // We return the shared service but set a fresh provider
        return MCPService.shared
    }

    // MARK: - List Agents

    @Suite("List Agents")
    struct ListAgentsTests {

        @Test("returns only same workspace agents")
        func returnsOnlySameWorkspaceAgents() async {
            let service = MCPService.shared

            // Create two workspaces with different agents
            var agent1 = Agent(name: "Agent1", folder: "/path/1")
            agent1.isRegistered = true
            var agent2 = Agent(name: "Agent2", folder: "/path/2")
            agent2.isRegistered = true
            var agent3 = Agent(name: "Agent3", folder: "/path/3")
            agent3.isRegistered = true

            let workspace1 = Workspace(name: "WS1", agentIds: [agent1.id, agent2.id])
            let workspace2 = Workspace(name: "WS2", agentIds: [agent3.id])

            let provider = MockAgentDataProvider(
                agents: [agent1, agent2, agent3],
                workspaces: [workspace1, workspace2]
            )

            await service.setAgentDataProvider(provider)

            // List agents from agent1's perspective (workspace1)
            let agents = await service.listAgents(callerAgentId: agent1.id.uuidString)

            #expect(agents.count == 2)
            #expect(agents.contains { $0.name == "Agent1" })
            #expect(agents.contains { $0.name == "Agent2" })
            #expect(!agents.contains { $0.name == "Agent3" })
        }

        @Test("returns empty for invalid caller id")
        func returnsEmptyForInvalidCaller() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let agents = await service.listAgents(callerAgentId: "invalid-uuid")

            #expect(agents.isEmpty)
        }
    }

    // MARK: - Register Agent

    @Suite("Register Agent")
    struct RegisterAgentTests {

        @Test("validates uuid format")
        func validatesUuidFormat() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let result = await service.registerAgent(agentId: "not-a-uuid")

            #expect(result == false)
        }

        @Test("returns false for non-existent agent")
        func returnsFalseForNonExistent() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let result = await service.registerAgent(agentId: UUID().uuidString)

            #expect(result == false)
        }

        @Test("marks agent as registered on success")
        func marksAgentAsRegistered() async {
            let service = MCPService.shared

            var agent = Agent(name: "Test", folder: "/path")
            agent.isRegistered = false

            let provider = MockAgentDataProvider(agents: [agent])
            await service.setAgentDataProvider(provider)

            let result = await service.registerAgent(agentId: agent.id.uuidString)

            #expect(result == true)
            let isRegistered = await provider.containsRegisteredAgent(agent.id)
            #expect(isRegistered)
        }
    }

    // MARK: - Send Message

    @Suite("Send Message")
    struct SendMessageTests {

        @Test("validates sender is registered")
        func validatesSenderRegistered() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = false
            var recipient = Agent(name: "Recipient", folder: "/path/recipient")
            recipient.isRegistered = true

            let workspace = Workspace(name: "Test", agentIds: [sender.id, recipient.id])
            let provider = MockAgentDataProvider(
                agents: [sender, recipient],
                workspaces: [workspace]
            )
            await service.setAgentDataProvider(provider)

            let result = await service.sendMessage(
                from: sender.id.uuidString,
                to: recipient.id.uuidString,
                content: "Hello"
            )

            #expect(result == false)
        }

        @Test("validates recipient exists in same workspace")
        func validatesRecipientInSameWorkspace() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = true
            var recipient = Agent(name: "Recipient", folder: "/path/recipient")
            recipient.isRegistered = true

            // Put them in different workspaces
            let workspace1 = Workspace(name: "WS1", agentIds: [sender.id])
            let workspace2 = Workspace(name: "WS2", agentIds: [recipient.id])

            let provider = MockAgentDataProvider(
                agents: [sender, recipient],
                workspaces: [workspace1, workspace2]
            )
            await service.setAgentDataProvider(provider)

            let result = await service.sendMessage(
                from: sender.id.uuidString,
                to: recipient.id.uuidString,
                content: "Hello"
            )

            #expect(result == false)
        }

        @Test("succeeds with valid sender and recipient")
        func succeedsWithValidSenderAndRecipient() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = true
            var recipient = Agent(name: "Recipient", folder: "/path/recipient")
            recipient.isRegistered = true

            let workspace = Workspace(name: "Test", agentIds: [sender.id, recipient.id])
            let provider = MockAgentDataProvider(
                agents: [sender, recipient],
                workspaces: [workspace]
            )
            await service.setAgentDataProvider(provider)

            let result = await service.sendMessage(
                from: sender.id.uuidString,
                to: recipient.id.uuidString,
                content: "Hello"
            )

            #expect(result == true)
        }
    }

    // MARK: - Broadcast Message

    @Suite("Broadcast Message")
    struct BroadcastMessageTests {

        @Test("excludes sender from recipients")
        func excludesSender() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = true
            var recipient1 = Agent(name: "Recipient1", folder: "/path/r1")
            recipient1.isRegistered = true
            var recipient2 = Agent(name: "Recipient2", folder: "/path/r2")
            recipient2.isRegistered = true

            let workspace = Workspace(name: "Test", agentIds: [sender.id, recipient1.id, recipient2.id])
            let provider = MockAgentDataProvider(
                agents: [sender, recipient1, recipient2],
                workspaces: [workspace]
            )
            await service.setAgentDataProvider(provider)

            let count = await service.broadcastMessage(
                from: sender.id.uuidString,
                content: "Broadcast"
            )

            #expect(count == 2)  // sender excluded
        }

        @Test("only broadcasts to registered agents")
        func onlyBroadcastsToRegistered() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = true
            var registered = Agent(name: "Registered", folder: "/path/r")
            registered.isRegistered = true
            var unregistered = Agent(name: "Unregistered", folder: "/path/u")
            unregistered.isRegistered = false

            let workspace = Workspace(name: "Test", agentIds: [sender.id, registered.id, unregistered.id])
            let provider = MockAgentDataProvider(
                agents: [sender, registered, unregistered],
                workspaces: [workspace]
            )
            await service.setAgentDataProvider(provider)

            let count = await service.broadcastMessage(
                from: sender.id.uuidString,
                content: "Broadcast"
            )

            #expect(count == 1)  // only registered recipient
        }

        @Test("returns 0 for unregistered sender")
        func returnsZeroForUnregisteredSender() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = false

            let workspace = Workspace(name: "Test", agentIds: [sender.id])
            let provider = MockAgentDataProvider(
                agents: [sender],
                workspaces: [workspace]
            )
            await service.setAgentDataProvider(provider)

            let count = await service.broadcastMessage(
                from: sender.id.uuidString,
                content: "Broadcast"
            )

            #expect(count == 0)
        }

        @Test("only broadcasts to same workspace")
        func onlyBroadcastsToSameWorkspace() async {
            let service = MCPService.shared

            var sender = Agent(name: "Sender", folder: "/path/sender")
            sender.isRegistered = true
            var sameWS = Agent(name: "SameWS", folder: "/path/same")
            sameWS.isRegistered = true
            var differentWS = Agent(name: "DiffWS", folder: "/path/diff")
            differentWS.isRegistered = true

            let workspace1 = Workspace(name: "WS1", agentIds: [sender.id, sameWS.id])
            let workspace2 = Workspace(name: "WS2", agentIds: [differentWS.id])

            let provider = MockAgentDataProvider(
                agents: [sender, sameWS, differentWS],
                workspaces: [workspace1, workspace2]
            )
            await service.setAgentDataProvider(provider)

            let count = await service.broadcastMessage(
                from: sender.id.uuidString,
                content: "Broadcast"
            )

            #expect(count == 1)  // only sameWS
        }
    }

    // MARK: - Agent Creation Validation

    @Suite("Agent Creation Validation")
    struct AgentCreationValidationTests {

        @Test("validates branchName when createWorktree is true")
        func validatesBranchNameWhenCreateWorktree() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let result = await service.createAgent(
                name: "Test",
                icon: nil,
                agentType: "claude",
                repoPath: "/path/to/repo",
                createWorktree: true,
                branchName: nil  // Missing branch name
            )

            #expect(result.success == false)
            #expect(result.message.contains("branchName"))
        }

        @Test("validates branchName is not empty when createWorktree is true")
        func validatesBranchNameNotEmpty() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let result = await service.createAgent(
                name: "Test",
                icon: nil,
                agentType: "claude",
                repoPath: "/path/to/repo",
                createWorktree: true,
                branchName: ""  // Empty branch name
            )

            #expect(result.success == false)
            #expect(result.message.contains("branchName"))
        }
    }

    // MARK: - Find Agent

    @Suite("Find Agent")
    struct FindAgentTests {

        @Test("finds agent by UUID")
        func findsByUUID() async {
            let service = MCPService.shared

            let agent = Agent(name: "Test", folder: "/path")
            let provider = MockAgentDataProvider(agents: [agent])
            await service.setAgentDataProvider(provider)

            let found = await service.findAgent(byNameOrId: agent.id.uuidString)

            #expect(found != nil)
            #expect(found?.id == agent.id)
        }

        @Test("finds agent by name case-insensitive")
        func findsByNameCaseInsensitive() async {
            let service = MCPService.shared

            let agent = Agent(name: "TestAgent", folder: "/path")
            let provider = MockAgentDataProvider(agents: [agent])
            await service.setAgentDataProvider(provider)

            let found = await service.findAgent(byNameOrId: "testagent")

            #expect(found != nil)
            #expect(found?.name == "TestAgent")
        }

        @Test("returns nil for non-existent agent")
        func returnsNilForNonExistent() async {
            let service = MCPService.shared

            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let found = await service.findAgent(byNameOrId: "nonexistent")

            #expect(found == nil)
        }
    }

    // MARK: - Unregister Agent

    @Suite("Unregister Agent")
    struct UnregisterAgentTests {

        @Test("validates uuid format")
        func validatesUuidFormat() async {
            let service = MCPService.shared
            let provider = MockAgentDataProvider()
            await service.setAgentDataProvider(provider)

            let result = await service.unregisterAgent(agentId: "not-a-uuid")

            #expect(result == false)
        }

        @Test("marks agent as unregistered")
        func marksAgentAsUnregistered() async {
            let service = MCPService.shared

            var agent = Agent(name: "Test", folder: "/path")
            agent.isRegistered = true

            let provider = MockAgentDataProvider(agents: [agent])
            await provider.registerAgentForTest(agent.id)
            await service.setAgentDataProvider(provider)

            let result = await service.unregisterAgent(agentId: agent.id.uuidString)

            #expect(result == true)
            let isRegistered = await provider.containsRegisteredAgent(agent.id)
            #expect(!isRegistered)
        }
    }
}
