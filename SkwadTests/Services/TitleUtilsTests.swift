import XCTest
@testable import Skwad

final class TitleUtilsTests: XCTestCase {

    // MARK: - isRegistrationPrompt

    func testDetectsTeamOfAgentsPrompt() {
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("You are part of a team of agents called a skwad"))
    }

    func testDetectsRegisterWithSkwadPrompt() {
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("Register with the skwad using agent ID abc-123"))
    }

    func testDetectsListAgentsPrompt() {
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("List other agents names and project (no ID) in a table"))
    }

    func testDetectsCheckInboxPrompt() {
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("Check your inbox for messages from other agents"))
    }

    func testRegistrationCheckIsCaseInsensitive() {
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("YOU ARE PART OF A TEAM OF AGENTS"))
        XCTAssertTrue(TitleUtils.isRegistrationPrompt("REGISTER WITH THE SKWAD"))
    }

    func testNormalTextIsNotRegistrationPrompt() {
        XCTAssertFalse(TitleUtils.isRegistrationPrompt("Fix the login bug"))
    }

    // MARK: - isValidTitle

    func testEmptyStringIsNotValid() {
        XCTAssertFalse(TitleUtils.isValidTitle(""))
        XCTAssertFalse(TitleUtils.isValidTitle("   "))
    }

    func testRegistrationPromptIsNotValid() {
        XCTAssertFalse(TitleUtils.isValidTitle("You are part of a team of agents"))
    }

    func testLocalCommandIsNotValid() {
        XCTAssertFalse(TitleUtils.isValidTitle("<local-command-stdout></local-command-stdout>"))
    }

    func testClearIsNotValid() {
        XCTAssertFalse(TitleUtils.isValidTitle("/clear"))
    }

    func testNormalTextIsValid() {
        XCTAssertTrue(TitleUtils.isValidTitle("Fix the login bug"))
    }

    func testCommandTitlesAreValid() {
        XCTAssertTrue(TitleUtils.isValidTitle("/review focus on error handling"))
        XCTAssertTrue(TitleUtils.isValidTitle("/design new feature"))
    }

    // MARK: - extractTitle

    func testExtractsFirstLine() {
        XCTAssertEqual(TitleUtils.extractTitle("First line\nSecond line"), "First line")
    }

    func testTruncatesLongTitles() {
        let long = String(repeating: "a", count: 100)
        let result = TitleUtils.extractTitle(long)
        XCTAssertEqual(result?.count, 80)
        XCTAssertTrue(result?.hasSuffix("...") ?? false)
    }

    func testPreservesShortTitles() {
        XCTAssertEqual(TitleUtils.extractTitle("Fix the bug"), "Fix the bug")
    }

    func testReturnsNilForEmpty() {
        XCTAssertNil(TitleUtils.extractTitle(""))
        XCTAssertNil(TitleUtils.extractTitle("   "))
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(TitleUtils.extractTitle("  Fix the bug  "), "Fix the bug")
    }

    // MARK: - truncate

    func testTruncateShortText() {
        XCTAssertEqual(TitleUtils.truncate("short"), "short")
    }

    func testTruncateLongText() {
        let long = String(repeating: "x", count: 100)
        let result = TitleUtils.truncate(long)
        XCTAssertEqual(result.count, 80)
        XCTAssertTrue(result.hasSuffix("..."))
    }

    func testTruncateExactly80() {
        let exact = String(repeating: "a", count: 80)
        XCTAssertEqual(TitleUtils.truncate(exact), exact)
    }

    func testTruncateTakesFirstLine() {
        XCTAssertEqual(TitleUtils.truncate("first\nsecond"), "first")
    }
}
