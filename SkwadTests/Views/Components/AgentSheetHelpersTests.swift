import XCTest
import Foundation
@testable import Skwad

final class AgentSheetHelpersTests: XCTestCase {

    // MARK: - Path Shortening

    /// Helper function that mirrors the shortenedPath logic from AgentSheet
    private func shortenPath(_ path: String) -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func testReplacesHomeWithTilde() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
            // Skip test if HOME not set
            return
        }

        let path = "\(home)/src/project"
        let shortened = shortenPath(path)

        XCTAssertEqual(shortened, "~/src/project")
    }

    func testPreservesPathsNotUnderHome() {
        let path = "/tmp/some/path"
        let shortened = shortenPath(path)

        XCTAssertEqual(shortened, "/tmp/some/path")
    }

    func testHandlesHomeDirectoryItself() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
            return
        }

        let shortened = shortenPath(home)

        XCTAssertEqual(shortened, "~")
    }

    func testHandlesPathsWithTrailingSlash() {
        guard let home = ProcessInfo.processInfo.environment["HOME"] else {
            return
        }

        let path = "\(home)/src/project/"
        let shortened = shortenPath(path)

        XCTAssertEqual(shortened, "~/src/project/")
    }

    // MARK: - Validation

    /// Validation logic extracted from AgentSheet
    private func validateFolder(_ selectedFolder: String) -> String? {
        if selectedFolder.isEmpty {
            return "Please select a folder for the agent."
        }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: selectedFolder, isDirectory: &isDirectory) || !isDirectory.boolValue {
            return "The selected folder does not exist."
        }

        return nil  // No error
    }

    func testRequiresFolderSelection() {
        let error = validateFolder("")

        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("select") == true)
    }

    func testValidatesFolderExists() {
        let error = validateFolder("/this/path/definitely/does/not/exist/12345")

        XCTAssertNotNil(error)
        XCTAssertTrue(error?.contains("does not exist") == true)
    }

    func testAcceptsValidFolder() {
        // /tmp should exist on macOS
        let error = validateFolder("/tmp")

        XCTAssertNil(error)
    }

    func testRejectsFileAsFolder() {
        // Create a temp file
        let tempFile = NSTemporaryDirectory() + "test_file_\(UUID().uuidString)"
        FileManager.default.createFile(atPath: tempFile, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: tempFile) }

        let error = validateFolder(tempFile)

        XCTAssertNotNil(error)
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
