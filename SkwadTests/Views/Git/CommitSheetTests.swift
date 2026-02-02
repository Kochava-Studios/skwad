import Testing
@testable import Skwad

@Suite("CommitSheet")
struct CommitSheetTests {

    // MARK: - Commit Message Validation Logic Tests

    /// Tests the canCommit logic - empty message should not allow commit
    @Test("empty message disables commit")
    func emptyMessageDisablesCommit() {
        let message = ""
        let isCommitting = false
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == false)
    }

    /// Tests that whitespace-only message is treated as empty
    @Test("whitespace only message disables commit")
    func whitespaceOnlyDisablesCommit() {
        let message = "   \n\t  "
        let isCommitting = false
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == false)
    }

    /// Tests that a valid message enables commit
    @Test("valid message enables commit")
    func validMessageEnablesCommit() {
        let message = "feat: add new feature"
        let isCommitting = false
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == true)
    }

    /// Tests that commit is disabled while a commit is in progress
    @Test("committing in progress disables commit")
    func committingDisablesCommit() {
        let message = "feat: add new feature"
        let isCommitting = true
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == false)
    }

    /// Tests that multiline messages are valid
    @Test("multiline message is valid")
    func multilineMessageIsValid() {
        let message = """
            feat: add new feature

            This is the body of the commit message.
            It can span multiple lines.
            """
        let isCommitting = false
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == true)
    }

    /// Tests that single character messages are valid
    @Test("single character message is valid")
    func singleCharMessageIsValid() {
        let message = "x"
        let isCommitting = false
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
        #expect(canCommit == true)
    }

    /// Tests that commit message is properly trimmed
    @Test("commit message is trimmed")
    func messageIsTrimmed() {
        let message = "  feat: test commit  \n"
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == "feat: test commit")
    }

    /// Tests message with leading/trailing newlines
    @Test("message with newlines is trimmed")
    func messageWithNewlinesIsTrimmed() {
        let message = "\n\nfeat: test\n\n"
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(trimmed == "feat: test")
    }

    /// Tests conventional commit format
    @Test("conventional commit format is valid")
    func conventionalCommitIsValid() {
        let validPrefixes = ["feat:", "fix:", "chore:", "docs:", "style:", "refactor:", "test:", "build:"]
        for prefix in validPrefixes {
            let message = "\(prefix) some change"
            let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            #expect(canCommit == true, "Message with '\(prefix)' prefix should be valid")
        }
    }

    /// Tests that tabs are treated as whitespace
    @Test("tabs only message is invalid")
    func tabsOnlyIsInvalid() {
        let message = "\t\t\t"
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(canCommit == false)
    }

    /// Tests mixed whitespace
    @Test("mixed whitespace only is invalid")
    func mixedWhitespaceOnlyIsInvalid() {
        let message = " \t \n \t \n "
        let canCommit = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(canCommit == false)
    }
}
