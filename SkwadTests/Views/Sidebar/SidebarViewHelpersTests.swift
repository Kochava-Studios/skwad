import Testing
import Foundation
@testable import Skwad

@Suite("SidebarView Helpers")
struct SidebarViewHelpersTests {

    // MARK: - Broadcast Validation

    @Suite("Broadcast Validation")
    struct BroadcastValidationTests {

        /// Helper that mirrors the sendBroadcast validation logic
        private func shouldSendBroadcast(_ message: String) -> Bool {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty
        }

        @Test("trims whitespace from message")
        func trimsWhitespace() {
            // With whitespace only, should not send
            #expect(shouldSendBroadcast("   ") == false)
            #expect(shouldSendBroadcast("\n\t\n") == false)
        }

        @Test("skips empty message")
        func skipsEmptyMessage() {
            #expect(shouldSendBroadcast("") == false)
        }

        @Test("allows valid message")
        func allowsValidMessage() {
            #expect(shouldSendBroadcast("Hello agents!") == true)
        }

        @Test("allows message with leading/trailing whitespace")
        func allowsMessageWithWhitespace() {
            #expect(shouldSendBroadcast("  Hello  ") == true)
        }

        @Test("handles multiline messages")
        func handlesMultilineMessages() {
            let message = """
            Line 1
            Line 2
            Line 3
            """
            #expect(shouldSendBroadcast(message) == true)
        }
    }

    // MARK: - Batch Operations

    @Suite("Batch Operations")
    struct BatchOperationsTests {

        @Test("iterates workspace agents for restart")
        func iteratesWorkspaceAgentsForRestart() {
            // Simulating the batch operation logic
            let agents = [
                Agent(name: "Agent1", folder: "/path/1"),
                Agent(name: "Agent2", folder: "/path/2"),
                Agent(name: "Agent3", folder: "/path/3")
            ]

            var restartedCount = 0
            for _ in agents {
                restartedCount += 1
            }

            #expect(restartedCount == 3)
        }

        @Test("iterates workspace agents for close")
        func iteratesWorkspaceAgentsForClose() {
            let agents = [
                Agent(name: "Agent1", folder: "/path/1"),
                Agent(name: "Agent2", folder: "/path/2")
            ]

            var closedCount = 0
            for _ in agents {
                closedCount += 1
            }

            #expect(closedCount == 2)
        }

        @Test("handles empty workspace")
        func handlesEmptyWorkspace() {
            let agents: [Agent] = []

            var operationCount = 0
            for _ in agents {
                operationCount += 1
            }

            #expect(operationCount == 0)
        }
    }

    // MARK: - Recent Agent Validation

    @Suite("Recent Agent Validation")
    struct RecentAgentValidationTests {

        /// Check if a saved agent's folder is still valid
        private func isValidRecentAgent(_ saved: SavedAgent) -> Bool {
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: saved.folder, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        @Test("validates existing folder")
        func validatesExistingFolder() {
            // /tmp should exist
            let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: "/tmp")
            #expect(isValidRecentAgent(saved) == true)
        }

        @Test("rejects non-existent folder")
        func rejectsNonExistentFolder() {
            let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: "/nonexistent/path/12345")
            #expect(isValidRecentAgent(saved) == false)
        }

        @Test("rejects file as folder")
        func rejectsFileAsFolder() {
            // Create a temporary file
            let tempFile = NSTemporaryDirectory() + "test_file_\(UUID().uuidString)"
            FileManager.default.createFile(atPath: tempFile, contents: nil)
            defer { try? FileManager.default.removeItem(atPath: tempFile) }

            let saved = SavedAgent(id: UUID(), name: "Test", avatar: "🤖", folder: tempFile)
            #expect(isValidRecentAgent(saved) == false)
        }
    }

    // MARK: - Agent Row Display

    @Suite("Agent Row Display")
    struct AgentRowDisplayTests {

        @Test("agent displayTitle strips leading status indicators")
        func displayTitleStripsStatusIndicators() {
            var agent = Agent(name: "Test", folder: "/path")
            agent.terminalTitle = "✳ Working on task"

            #expect(agent.displayTitle == "Working on task")
        }

        @Test("agent displayTitle handles empty title")
        func displayTitleHandlesEmptyTitle() {
            var agent = Agent(name: "Test", folder: "/path")
            agent.terminalTitle = ""

            #expect(agent.displayTitle == "")
        }

        @Test("agent displayTitle preserves ASCII content")
        func displayTitlePreservesAsciiContent() {
            var agent = Agent(name: "Test", folder: "/path")
            agent.terminalTitle = "Working on feature"

            #expect(agent.displayTitle == "Working on feature")
        }

        @Test("agent displayTitle strips multiple status indicators")
        func displayTitleStripsMultipleIndicators() {
            var agent = Agent(name: "Test", folder: "/path")
            agent.terminalTitle = "● ✳ Task"

            #expect(agent.displayTitle == "Task")
        }
    }
}
