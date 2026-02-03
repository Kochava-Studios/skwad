import Testing
import Foundation
@testable import Skwad

@Suite("AgentSheet Helpers")
struct AgentSheetHelpersTests {

    // MARK: - Path Shortening

    @Suite("Path Shortening")
    struct PathShorteningTests {

        /// Helper function that mirrors the shortenedPath logic from AgentSheet
        private func shortenPath(_ path: String) -> String {
            if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
                return "~" + path.dropFirst(home.count)
            }
            return path
        }

        @Test("replaces home with tilde")
        func replacesHomeWithTilde() {
            guard let home = ProcessInfo.processInfo.environment["HOME"] else {
                // Skip test if HOME not set
                return
            }

            let path = "\(home)/src/project"
            let shortened = shortenPath(path)

            #expect(shortened == "~/src/project")
        }

        @Test("preserves paths not under home")
        func preservesNonHomePaths() {
            let path = "/tmp/some/path"
            let shortened = shortenPath(path)

            #expect(shortened == "/tmp/some/path")
        }

        @Test("handles home directory itself")
        func handlesHomeDirectoryItself() {
            guard let home = ProcessInfo.processInfo.environment["HOME"] else {
                return
            }

            let shortened = shortenPath(home)

            #expect(shortened == "~")
        }

        @Test("handles paths with trailing slash")
        func handlesTrailingSlash() {
            guard let home = ProcessInfo.processInfo.environment["HOME"] else {
                return
            }

            let path = "\(home)/src/project/"
            let shortened = shortenPath(path)

            #expect(shortened == "~/src/project/")
        }
    }

    // MARK: - Validation

    @Suite("Validation")
    struct ValidationTests {

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

        @Test("requires folder selection")
        func requiresFolderSelection() {
            let error = validateFolder("")

            #expect(error != nil)
            #expect(error?.contains("select") == true)
        }

        @Test("validates folder exists")
        func validatesFolderExists() {
            let error = validateFolder("/this/path/definitely/does/not/exist/12345")

            #expect(error != nil)
            #expect(error?.contains("does not exist") == true)
        }

        @Test("accepts valid folder")
        func acceptsValidFolder() {
            // /tmp should exist on macOS
            let error = validateFolder("/tmp")

            #expect(error == nil)
        }

        @Test("rejects file as folder")
        func rejectsFileAsFolder() {
            // Create a temp file
            let tempFile = NSTemporaryDirectory() + "test_file_\(UUID().uuidString)"
            FileManager.default.createFile(atPath: tempFile, contents: nil)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }

            let error = validateFolder(tempFile)

            #expect(error != nil)
        }
    }

    // MARK: - AgentPrefill

    @Suite("AgentPrefill")
    struct AgentPrefillTests {

        @Test("creates unique id")
        func createsUniqueId() {
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

            #expect(prefill1.id != prefill2.id)
        }

        @Test("stores all properties")
        func storesAllProperties() {
            let insertId = UUID()
            let prefill = AgentPrefill(
                name: "MyAgent",
                avatar: "🤖",
                folder: "/path/to/project",
                agentType: "codex",
                insertAfterId: insertId
            )

            #expect(prefill.name == "MyAgent")
            #expect(prefill.avatar == "🤖")
            #expect(prefill.folder == "/path/to/project")
            #expect(prefill.agentType == "codex")
            #expect(prefill.insertAfterId == insertId)
        }

        @Test("handles nil avatar")
        func handlesNilAvatar() {
            let prefill = AgentPrefill(
                name: "Test",
                avatar: nil,
                folder: "/path",
                agentType: "claude",
                insertAfterId: nil
            )

            #expect(prefill.avatar == nil)
        }
    }
}
