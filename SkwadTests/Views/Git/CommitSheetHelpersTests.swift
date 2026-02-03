import Testing
import Foundation
@testable import Skwad

@Suite("CommitSheet Helpers")
struct CommitSheetHelpersTests {

    // MARK: - Can Commit Validation

    /// Helper that mirrors the canCommit logic from CommitSheet
    static func canCommit(message: String, isCommitting: Bool) -> Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
    }

    @Suite("Can Commit Validation")
    struct CanCommitValidationTests {

        @Test("empty message cannot commit")
        func emptyMessageCannotCommit() {
            #expect(CommitSheetHelpersTests.canCommit(message: "", isCommitting: false) == false)
        }

        @Test("whitespace only message cannot commit")
        func whitespaceOnlyCannotCommit() {
            #expect(CommitSheetHelpersTests.canCommit(message: "   ", isCommitting: false) == false)
            #expect(CommitSheetHelpersTests.canCommit(message: "\n\t\n", isCommitting: false) == false)
            #expect(CommitSheetHelpersTests.canCommit(message: "  \t  ", isCommitting: false) == false)
        }

        @Test("valid message can commit")
        func validMessageCanCommit() {
            #expect(CommitSheetHelpersTests.canCommit(message: "Fix bug", isCommitting: false) == true)
        }

        @Test("message with leading/trailing whitespace can commit")
        func messageWithWhitespaceCanCommit() {
            #expect(CommitSheetHelpersTests.canCommit(message: "  Fix bug  ", isCommitting: false) == true)
        }

        @Test("cannot commit while committing")
        func cannotCommitWhileCommitting() {
            #expect(CommitSheetHelpersTests.canCommit(message: "Fix bug", isCommitting: true) == false)
        }

        @Test("empty message and committing both block")
        func emptyAndCommittingBothBlock() {
            #expect(CommitSheetHelpersTests.canCommit(message: "", isCommitting: true) == false)
        }

        @Test("multiline message can commit")
        func multilineMessageCanCommit() {
            let message = """
            feat: add new feature

            This is the body of the commit message
            with multiple lines.
            """
            #expect(CommitSheetHelpersTests.canCommit(message: message, isCommitting: false) == true)
        }

        @Test("single character message can commit")
        func singleCharCanCommit() {
            #expect(CommitSheetHelpersTests.canCommit(message: "x", isCommitting: false) == true)
        }
    }
}
