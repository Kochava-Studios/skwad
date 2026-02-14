import XCTest
import Foundation
@testable import Skwad

final class CommitSheetHelpersTests: XCTestCase {

    // MARK: - Can Commit Validation

    func testEmptyMessageCannotCommit() {
        XCTAssertFalse(CommitSheet.canCommit(message: "", isCommitting: false))
    }

    func testWhitespaceOnlyMessageCannotCommit() {
        XCTAssertFalse(CommitSheet.canCommit(message: "   ", isCommitting: false))
        XCTAssertFalse(CommitSheet.canCommit(message: "\n\t\n", isCommitting: false))
        XCTAssertFalse(CommitSheet.canCommit(message: "  \t  ", isCommitting: false))
    }

    func testValidMessageCanCommit() {
        XCTAssertTrue(CommitSheet.canCommit(message: "Fix bug", isCommitting: false))
    }

    func testMessageWithLeadingTrailingWhitespaceCanCommit() {
        XCTAssertTrue(CommitSheet.canCommit(message: "  Fix bug  ", isCommitting: false))
    }

    func testCannotCommitWhileCommitting() {
        XCTAssertFalse(CommitSheet.canCommit(message: "Fix bug", isCommitting: true))
    }

    func testEmptyMessageAndCommittingBothBlock() {
        XCTAssertFalse(CommitSheet.canCommit(message: "", isCommitting: true))
    }

    func testMultilineMessageCanCommit() {
        let message = """
        feat: add new feature

        This is the body of the commit message
        with multiple lines.
        """
        XCTAssertTrue(CommitSheet.canCommit(message: message, isCommitting: false))
    }

    func testSingleCharacterMessageCanCommit() {
        XCTAssertTrue(CommitSheet.canCommit(message: "x", isCommitting: false))
    }
}
