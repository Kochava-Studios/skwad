import XCTest
import Foundation
@testable import Skwad

final class CommitSheetHelpersTests: XCTestCase {

    // MARK: - Can Commit Validation

    /// Helper that mirrors the canCommit logic from CommitSheet
    static func canCommit(message: String, isCommitting: Bool) -> Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCommitting
    }

    func testEmptyMessageCannotCommit() {
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "", isCommitting: false))
    }

    func testWhitespaceOnlyMessageCannotCommit() {
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "   ", isCommitting: false))
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "\n\t\n", isCommitting: false))
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "  \t  ", isCommitting: false))
    }

    func testValidMessageCanCommit() {
        XCTAssertTrue(CommitSheetHelpersTests.canCommit(message: "Fix bug", isCommitting: false))
    }

    func testMessageWithLeadingTrailingWhitespaceCanCommit() {
        XCTAssertTrue(CommitSheetHelpersTests.canCommit(message: "  Fix bug  ", isCommitting: false))
    }

    func testCannotCommitWhileCommitting() {
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "Fix bug", isCommitting: true))
    }

    func testEmptyMessageAndCommittingBothBlock() {
        XCTAssertFalse(CommitSheetHelpersTests.canCommit(message: "", isCommitting: true))
    }

    func testMultilineMessageCanCommit() {
        let message = """
        feat: add new feature

        This is the body of the commit message
        with multiple lines.
        """
        XCTAssertTrue(CommitSheetHelpersTests.canCommit(message: message, isCommitting: false))
    }

    func testSingleCharacterMessageCanCommit() {
        XCTAssertTrue(CommitSheetHelpersTests.canCommit(message: "x", isCommitting: false))
    }
}
