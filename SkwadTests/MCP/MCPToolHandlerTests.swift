import XCTest
@testable import Skwad

final class MCPToolHandlerTests: XCTestCase {

    private var coordinator: AgentCoordinator!
    private var handler: MCPToolHandler!

    override func setUp() async throws {
        coordinator = AgentCoordinator.shared
        handler = MCPToolHandler(mcpService: coordinator)
    }

    // MARK: - Tool Registration

    func testViewMermaidToolIsRegistered() async {
        let tools = await handler.listTools()
        let toolNames = tools.map { $0.name }
        XCTAssertTrue(toolNames.contains("view-mermaid"))
    }

    func testViewMermaidToolHasCorrectSchema() async {
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "view-mermaid" }!

        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties["agentId"])
        XCTAssertNotNil(properties["source"])
        XCTAssertNotNil(properties["title"])

        let required = tool.inputSchema.required
        XCTAssertTrue(required.contains("agentId"))
        XCTAssertTrue(required.contains("source"))
        XCTAssertFalse(required.contains("title"))
    }

    // MARK: - view-mermaid Argument Validation

    func testViewMermaidMissingAgentId() async {
        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("agentId"))
    }

    func testViewMermaidMissingSource() async {
        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": UUID().uuidString
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("source"))
    }

    func testViewMermaidUnknownAgent() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": UUID().uuidString,
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("not found"))
    }

    func testViewMermaidSuccess() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let agents = await provider.getAgents()
        let agentId = agents[0].id.uuidString

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": agentId,
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, false)
        XCTAssertTrue(result.content[0].text.contains("success"))
    }

    func testViewMermaidWithTitle() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let agents = await provider.getAgents()
        let agentId = agents[0].id.uuidString

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": agentId,
            "source": "graph TD; A-->B;",
            "title": "My Diagram"
        ])
        XCTAssertEqual(result.isError, false)
    }

    // MARK: - Unknown Tool

    func testUnknownToolReturnsError() async {
        let result = await handler.callTool(name: "nonexistent-tool", arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("Unknown tool"))
    }
}
