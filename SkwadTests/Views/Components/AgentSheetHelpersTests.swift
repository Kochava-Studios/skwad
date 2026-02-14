import XCTest
import Foundation
@testable import Skwad

final class AgentSheetHelpersTests: XCTestCase {

    // MARK: - Path Shortening (via PathUtils)

    func testReplacesHomeWithTilde() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let path = "\(home)/src/project"
        XCTAssertEqual(PathUtils.shortened(path), "~/src/project")
    }

    func testPreservesPathsNotUnderHome() {
        XCTAssertEqual(PathUtils.shortened("/tmp/some/path"), "/tmp/some/path")
    }

    func testHandlesHomeDirectoryItself() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        XCTAssertEqual(PathUtils.shortened(home), "~")
    }

    func testHandlesPathsWithTrailingSlash() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else { return }
        let path = "\(home)/src/project/"
        XCTAssertEqual(PathUtils.shortened(path), "~/src/project/")
    }

    // MARK: - AgentPrefill

    func testCreatesUniqueId() {
        let prefill1 = AgentPrefill(
            name: "Test",
            avatar: nil,
            folder: "/path",
            agentType: "claude",
            insertAfterId: nil
        )
        let prefill2 = AgentPrefill(
            name: "Test",
            avatar: nil,
            folder: "/path",
            agentType: "claude",
            insertAfterId: nil
        )

        XCTAssertNotEqual(prefill1.id, prefill2.id)
    }

    func testStoresAllProperties() {
        let insertId = UUID()
        let prefill = AgentPrefill(
            name: "MyAgent",
            avatar: "🤖",
            folder: "/path/to/project",
            agentType: "codex",
            insertAfterId: insertId
        )

        XCTAssertEqual(prefill.name, "MyAgent")
        XCTAssertEqual(prefill.avatar, "🤖")
        XCTAssertEqual(prefill.folder, "/path/to/project")
        XCTAssertEqual(prefill.agentType, "codex")
        XCTAssertEqual(prefill.insertAfterId, insertId)
    }

    func testHandlesNilAvatar() {
        let prefill = AgentPrefill(
            name: "Test",
            avatar: nil,
            folder: "/path",
            agentType: "claude",
            insertAfterId: nil
        )

        XCTAssertNil(prefill.avatar)
    }
}
