import XCTest
@testable import Skwad

@MainActor
final class FileSearchServiceTests: XCTestCase {

    func testSearchEmptyPatternReturnsEmpty() async {
        let service = FileSearchService()
        // Manually set cached files to simulate loaded state
        service.setCachedFiles(["a.swift", "b.swift"])
        await service.search(pattern: "")
        XCTAssertTrue(service.results.isEmpty)
    }

    func testSearchFindsMatchingFiles() async {
        let service = FileSearchService()
        service.setCachedFiles([
            "Models/Agent.swift",
            "Models/AgentManager.swift",
            "Views/ContentView.swift",
            "README.md",
        ])
        await service.search(pattern: "Agent")
        XCTAssertFalse(service.results.isEmpty)
        // Agent.swift and AgentManager.swift should match
        let paths = service.results.map(\.relativePath)
        XCTAssertTrue(paths.contains("Models/Agent.swift"))
        XCTAssertTrue(paths.contains("Models/AgentManager.swift"))
    }

    func testSearchResultsAreSortedByScore() async {
        let service = FileSearchService()
        service.setCachedFiles([
            "some/deep/path/with/agent/file.swift",
            "Agent.swift",
            "src/AgentManager.swift",
        ])
        await service.search(pattern: "Agent")
        XCTAssertFalse(service.results.isEmpty)
        // Should be sorted descending by score
        for i in 0..<(service.results.count - 1) {
            XCTAssertGreaterThanOrEqual(service.results[i].score, service.results[i + 1].score)
        }
    }

    func testSearchNoMatchReturnsEmpty() async {
        let service = FileSearchService()
        service.setCachedFiles(["README.md", "Makefile"])
        await service.search(pattern: "zzzzz")
        XCTAssertTrue(service.results.isEmpty)
    }

    func testResetClearsState() {
        let service = FileSearchService()
        service.setCachedFiles(["a.swift"])
        service.reset()
        XCTAssertTrue(service.results.isEmpty)
    }
}
