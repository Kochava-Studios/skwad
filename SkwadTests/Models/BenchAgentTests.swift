import XCTest
@testable import Skwad

final class BenchAgentTests: XCTestCase {

    @MainActor
    func testAddToBench() {
        let settings = AppSettings.shared
        let original = settings.benchAgents

        settings.benchAgents = []
        let agent = Agent(name: "TestAgent", avatar: "🤖", folder: "/path/to/folder", agentType: "claude")
        settings.addToBench(agent)

        XCTAssertEqual(settings.benchAgents.count, 1)
        XCTAssertEqual(settings.benchAgents.first?.name, "TestAgent")
        XCTAssertEqual(settings.benchAgents.first?.folder, "/path/to/folder")
        XCTAssertEqual(settings.benchAgents.first?.agentType, "claude")

        // Restore
        settings.benchAgents = original
    }

    @MainActor
    func testAddToBenchDeduplicatesByFolder() {
        let settings = AppSettings.shared
        let original = settings.benchAgents

        settings.benchAgents = []
        let agent1 = Agent(name: "Agent1", avatar: "🤖", folder: "/path/to/folder1", agentType: "claude")
        let agent2 = Agent(name: "Agent2", avatar: "🦊", folder: "/path/to/folder2", agentType: "codex")
        let agent1Updated = Agent(name: "Agent1Updated", avatar: "🐱", folder: "/path/to/folder1", agentType: "gemini")

        settings.addToBench(agent1)
        settings.addToBench(agent2)
        settings.addToBench(agent1Updated)

        // Should only have 2 entries (folder1 was deduplicated)
        XCTAssertEqual(settings.benchAgents.count, 2)
        // The updated agent should be first
        XCTAssertEqual(settings.benchAgents.first?.name, "Agent1Updated")
        XCTAssertEqual(settings.benchAgents.first?.agentType, "gemini")

        // Restore
        settings.benchAgents = original
    }

    @MainActor
    func testRemoveFromBench() {
        let settings = AppSettings.shared
        let original = settings.benchAgents

        settings.benchAgents = []
        let agent1 = Agent(name: "Agent1", folder: "/path/to/folder1")
        let agent2 = Agent(name: "Agent2", folder: "/path/to/folder2")
        settings.addToBench(agent1)
        settings.addToBench(agent2)

        let benchAgentToRemove = settings.benchAgents.first { $0.folder == "/path/to/folder1" }!
        settings.removeFromBench(benchAgentToRemove)

        XCTAssertEqual(settings.benchAgents.count, 1)
        XCTAssertEqual(settings.benchAgents.first?.folder, "/path/to/folder2")

        // Restore
        settings.benchAgents = original
    }

    @MainActor
    func testMoveBenchAgent() {
        let settings = AppSettings.shared
        let original = settings.benchAgents

        settings.benchAgents = []
        let agent1 = Agent(name: "Agent1", folder: "/path/to/folder1")
        let agent2 = Agent(name: "Agent2", folder: "/path/to/folder2")
        let agent3 = Agent(name: "Agent3", folder: "/path/to/folder3")
        settings.addToBench(agent1)
        settings.addToBench(agent2)
        settings.addToBench(agent3)

        // After addToBench (inserts at front): [agent3, agent2, agent1]
        XCTAssertEqual(settings.benchAgents[0].folder, "/path/to/folder3")
        XCTAssertEqual(settings.benchAgents[1].folder, "/path/to/folder2")
        XCTAssertEqual(settings.benchAgents[2].folder, "/path/to/folder1")

        // Move index 0 (agent3) to position 3 (end)
        settings.moveBenchAgent(from: IndexSet(integer: 0), to: 3)

        // After move: [agent2, agent1, agent3]
        XCTAssertEqual(settings.benchAgents[0].folder, "/path/to/folder2")
        XCTAssertEqual(settings.benchAgents[1].folder, "/path/to/folder1")
        XCTAssertEqual(settings.benchAgents[2].folder, "/path/to/folder3")

        // Restore
        settings.benchAgents = original
    }

    @MainActor
    func testUpdateBenchAgent() {
        let settings = AppSettings.shared
        let original = settings.benchAgents

        settings.benchAgents = []
        let agent = Agent(name: "Original", folder: "/path/to/folder")
        settings.addToBench(agent)

        let benchId = settings.benchAgents.first!.id
        settings.updateBenchAgent(id: benchId, name: "Renamed")

        XCTAssertEqual(settings.benchAgents.first?.name, "Renamed")

        // Restore
        settings.benchAgents = original
    }

    func testBenchAgentFromAgent() {
        let agent = Agent(name: "TestAgent", avatar: "🐱", folder: "/path/to/folder", agentType: "codex", shellCommand: "htop")
        let benchAgent = BenchAgent(from: agent)

        XCTAssertEqual(benchAgent.name, "TestAgent")
        XCTAssertEqual(benchAgent.avatar, "🐱")
        XCTAssertEqual(benchAgent.folder, "/path/to/folder")
        XCTAssertEqual(benchAgent.agentType, "codex")
        XCTAssertEqual(benchAgent.shellCommand, "htop")
        // ID should be different from the agent's ID
        XCTAssertNotEqual(benchAgent.id, agent.id)
    }

    func testBenchAgentFromAgentDefaultAvatar() {
        let agent = Agent(name: "NoAvatar", folder: "/path/to/folder")
        let benchAgent = BenchAgent(from: agent)

        XCTAssertEqual(benchAgent.avatar, "🤖")
    }

    func testBenchAgentCodableRoundTrip() throws {
        let original = BenchAgent(name: "Test", avatar: "🤖", folder: "/tmp", agentType: "claude", shellCommand: "top")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BenchAgent.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.avatar, original.avatar)
        XCTAssertEqual(decoded.folder, original.folder)
        XCTAssertEqual(decoded.agentType, original.agentType)
        XCTAssertEqual(decoded.shellCommand, original.shellCommand)
    }
}
