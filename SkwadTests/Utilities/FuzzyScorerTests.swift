import XCTest
@testable import Skwad

final class FuzzyScorerTests: XCTestCase {

    // MARK: - Shared file list used by all scoreFile tests

    private static let files = [
        "assets/logo.svg",
        "assets/agent.svg",
        "assets/anthropic.svg",
        "src/lib/assistant.ts",
        "src/lib/assistant.test.ts",
        "src/lib/assistant_playbook.ts",
        "src/lib/assistant_playbook.test.ts",
        "src/views/ContentView.swift",
        "src/views/SettingsView.swift",
        "src/views/SidebarView.swift",
        "src/models/Agent.swift",
        "src/models/AgentManager.swift",
        "src/git/GitCLI.swift",
        "src/git/GitRepository.swift",
        "README.md",
        "docs/readme_template.txt",
        "config/settings.json",
    ]

    /// Helper: given a pattern, return matched paths sorted by scoreFile descending
    private func ranked(_ pattern: String, in paths: [String] = FuzzyScorerTests.files) -> [String] {
        paths
            .compactMap { path -> (String, Int)? in
                guard let match = FuzzyScorer.scoreFile(pattern: pattern, path: path) else { return nil }
                return (path, match.score)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    // MARK: - Tests

    func testNoMatch() {
        XCTAssertEqual(ranked("zzz"), [])
    }

    func testAssistant() {
        XCTAssertEqual(ranked("assistant"), [
            "src/lib/assistant.ts",
            "src/lib/assistant.test.ts",
            "src/lib/assistant_playbook.ts",
            "src/lib/assistant_playbook.test.ts",
        ])
    }

    func testAssist() {
        XCTAssertEqual(ranked("assist"), [
            "src/lib/assistant.ts",
            "src/lib/assistant.test.ts",
            "src/lib/assistant_playbook.ts",
            "src/lib/assistant_playbook.test.ts",
        ])
    }

    func testAsstest() {
        XCTAssertEqual(ranked("asstest"), [
            "src/lib/assistant.test.ts",
            "src/lib/assistant_playbook.test.ts",
        ])
    }

    func testAssplte() {
        XCTAssertEqual(ranked("assplte"), [
            "src/lib/assistant_playbook.test.ts",
        ])
    }

    func testAgent() {
        // Both agent.svg and Agent.swift have exact stem "agent"
        // AgentManager has "agent" as prefix
        let results = ranked("agent")
        XCTAssertEqual(results, [
            "assets/agent.svg",
            "src/models/Agent.swift",
            "src/models/AgentManager.swift",
        ])
    }

    func testContentView() {
        XCTAssertEqual(ranked("content"), [
            "src/views/ContentView.swift",
        ])
    }

    func testGitCLI() {
        XCTAssertEqual(ranked("gitcli"), [
            "src/git/GitCLI.swift",
        ])
    }

    func testReadme() {
        XCTAssertEqual(ranked("readme"), [
            "README.md",
            "docs/readme_template.txt",
        ])
    }

    func testSettings() {
        XCTAssertEqual(ranked("settings"), [
            "config/settings.json",
            "src/views/SettingsView.swift",
        ])
    }

    func testAssistantDoesNotMatchAgent() {
        let files = [
            "assets/agent.ts",
            "css/assistant.css",
        ]
        XCTAssertEqual(ranked("assistant", in: files), [
            "css/assistant.css",
        ])
    }

    func testSingleCharA() {
        // Exact stem match first, then filename starting with 'a', then earlier 'a' beats later 'a'
        let files = [
            "src/zebra.txt",
            "src/Agent.swift",
            "banana.ts",
            "agent.ts",
        ]
        XCTAssertEqual(ranked("a", in: files), [
            "agent.ts",
            "src/Agent.swift",
            "banana.ts",
            "src/zebra.txt",
        ])
    }
}
