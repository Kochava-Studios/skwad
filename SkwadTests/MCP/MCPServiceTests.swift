import XCTest
import Foundation
@testable import Skwad

final class MCPServiceTests: XCTestCase {

    // Note: MCPService.shared is a singleton, so tests run with their own provider setup

    // MARK: - List Agents

    func testReturnsOnlySameWorkspaceAgents() async {
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

        XCTAssertEqual(agents.count, 2)
        XCTAssertTrue(agents.contains { $0.name == "Agent1" })
        XCTAssertTrue(agents.contains { $0.name == "Agent2" })
        XCTAssertFalse(agents.contains { $0.name == "Agent3" })
    }

    func testReturnsEmptyForInvalidCallerId() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let agents = await service.listAgents(callerAgentId: "invalid-uuid")

        XCTAssertTrue(agents.isEmpty)
    }

    // MARK: - Register Agent

    func testValidatesUuidFormat() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let result = await service.registerAgent(agentId: "not-a-uuid")

        XCTAssertFalse(result)
    }

    func testReturnsFalseForNonExistentAgent() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let result = await service.registerAgent(agentId: UUID().uuidString)

        XCTAssertFalse(result)
    }

    func testMarksAgentAsRegisteredOnSuccess() async {
        let service = MCPService.shared

        var agent = Agent(name: "Test", folder: "/path")
        agent.isRegistered = false

        let provider = MockAgentDataProvider(agents: [agent])
        await service.setAgentDataProvider(provider)

        let result = await service.registerAgent(agentId: agent.id.uuidString)

        XCTAssertTrue(result)
        let isRegistered = await provider.containsRegisteredAgent(agent.id)
        XCTAssertTrue(isRegistered)
    }

    // MARK: - Send Message

    func testValidatesSenderIsRegistered() async {
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

        XCTAssertFalse(result)
    }

    func testValidatesRecipientExistsInSameWorkspace() async {
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

        XCTAssertFalse(result)
    }

    func testSucceedsWithValidSenderAndRecipient() async {
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

        XCTAssertTrue(result)
    }

    // MARK: - Broadcast Message

    func testExcludesSenderFromBroadcast() async {
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

        XCTAssertEqual(count, 2)  // sender excluded
    }

    func testOnlyBroadcastsToRegisteredAgents() async {
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

        XCTAssertEqual(count, 1)  // only registered recipient
    }

    func testReturnsZeroForUnregisteredSender() async {
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

        XCTAssertEqual(count, 0)
    }

    func testOnlyBroadcastsToSameWorkspace() async {
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

        XCTAssertEqual(count, 1)  // only sameWS
    }

    // MARK: - Agent Creation Validation

    func testValidatesBranchNameWhenCreateWorktree() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let result = await service.createAgent(
            name: "Test",
            icon: nil,
            agentType: "claude",
            repoPath: "/path/to/repo",
            createWorktree: true,
            branchName: nil,  // Missing branch name
            createdBy: nil,
            companion: false,
            shellCommand: nil
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("branchName"))
    }

    func testValidatesBranchNameNotEmpty() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let result = await service.createAgent(
            name: "Test",
            icon: nil,
            agentType: "claude",
            repoPath: "/path/to/repo",
            createWorktree: true,
            branchName: "",  // Empty branch name
            createdBy: nil,
            companion: false,
            shellCommand: nil
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("branchName"))
    }

    // MARK: - Find Agent

    func testFindsByUUID() async {
        let service = MCPService.shared

        let agent = Agent(name: "Test", folder: "/path")
        let provider = MockAgentDataProvider(agents: [agent])
        await service.setAgentDataProvider(provider)

        let found = await service.findAgent(byNameOrId: agent.id.uuidString)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, agent.id)
    }

    func testFindsByNameCaseInsensitive() async {
        let service = MCPService.shared

        let agent = Agent(name: "TestAgent", folder: "/path")
        let provider = MockAgentDataProvider(agents: [agent])
        await service.setAgentDataProvider(provider)

        let found = await service.findAgent(byNameOrId: "testagent")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "TestAgent")
    }

    func testReturnsNilForNonExistentAgent() async {
        let service = MCPService.shared

        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let found = await service.findAgent(byNameOrId: "nonexistent")

        XCTAssertNil(found)
    }

    // MARK: - Unregister Agent

    func testUnregisterValidatesUuidFormat() async {
        let service = MCPService.shared
        let provider = MockAgentDataProvider()
        await service.setAgentDataProvider(provider)

        let result = await service.unregisterAgent(agentId: "not-a-uuid")

        XCTAssertFalse(result)
    }

    func testMarksAgentAsUnregistered() async {
        let service = MCPService.shared

        var agent = Agent(name: "Test", folder: "/path")
        agent.isRegistered = true

        let provider = MockAgentDataProvider(agents: [agent])
        await provider.registerAgentForTest(agent.id)
        await service.setAgentDataProvider(provider)

        let result = await service.unregisterAgent(agentId: agent.id.uuidString)

        XCTAssertTrue(result)
        let isRegistered = await provider.containsRegisteredAgent(agent.id)
        XCTAssertFalse(isRegistered)
    }
}
