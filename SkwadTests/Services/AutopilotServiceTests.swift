import XCTest
@testable import Skwad

final class AutopilotServiceTests: XCTestCase {

    // MARK: - parseResponse: binary

    func testParseResponseBinary() {
        XCTAssertEqual(AutopilotService.parseResponse("binary"), .binary)
    }

    func testParseResponseBinaryUppercase() {
        XCTAssertEqual(AutopilotService.parseResponse("Binary"), .binary)
    }

    func testParseResponseBinaryWithWhitespace() {
        XCTAssertEqual(AutopilotService.parseResponse("  binary\n"), .binary)
    }

    func testParseResponseBinaryWithExplanation() {
        XCTAssertEqual(AutopilotService.parseResponse("binary - the agent is asking for approval"), .binary)
    }

    // MARK: - parseResponse: open

    func testParseResponseOpen() {
        XCTAssertEqual(AutopilotService.parseResponse("open"), .open)
    }

    func testParseResponseOpenUppercase() {
        XCTAssertEqual(AutopilotService.parseResponse("Open"), .open)
    }

    func testParseResponseOpenWithWhitespace() {
        XCTAssertEqual(AutopilotService.parseResponse("  open\n"), .open)
    }

    func testParseResponseOpenWithExplanation() {
        XCTAssertEqual(AutopilotService.parseResponse("open - the agent is asking a question"), .open)
    }

    // MARK: - parseResponse: completed

    func testParseResponseCompleted() {
        XCTAssertEqual(AutopilotService.parseResponse("completed"), .completed)
    }

    func testParseResponseCompletedUppercase() {
        XCTAssertEqual(AutopilotService.parseResponse("Completed"), .completed)
    }

    func testParseResponseCompletedWithWhitespace() {
        XCTAssertEqual(AutopilotService.parseResponse("  completed\n"), .completed)
    }

    // MARK: - parseResponse: defaults to completed

    func testParseResponseEmptyDefaultsToCompleted() {
        XCTAssertEqual(AutopilotService.parseResponse(""), .completed)
    }

    func testParseResponseGarbageDefaultsToCompleted() {
        XCTAssertEqual(AutopilotService.parseResponse("maybe"), .completed)
    }

    func testParseResponseYesDefaultsToCompleted() {
        // Legacy "yes" response should not match binary
        XCTAssertEqual(AutopilotService.parseResponse("yes"), .completed)
    }

    func testParseResponseNoDefaultsToCompleted() {
        XCTAssertEqual(AutopilotService.parseResponse("no"), .completed)
    }

    // MARK: - isEmptyResponse

    func testIsEmptyResponseEmpty() {
        XCTAssertTrue(AutopilotService.isEmptyResponse(""))
    }

    func testIsEmptyResponseWhitespace() {
        XCTAssertTrue(AutopilotService.isEmptyResponse("   \n\t  "))
    }

    func testIsEmptyResponseEmptyKeyword() {
        XCTAssertTrue(AutopilotService.isEmptyResponse("EMPTY"))
    }

    func testIsEmptyResponseEmptyKeywordLowercase() {
        XCTAssertTrue(AutopilotService.isEmptyResponse("empty"))
    }

    func testIsEmptyResponseEmptyKeywordMixedCase() {
        XCTAssertTrue(AutopilotService.isEmptyResponse("Empty"))
    }

    func testIsEmptyResponseEmptyKeywordWithWhitespace() {
        XCTAssertTrue(AutopilotService.isEmptyResponse("  EMPTY  "))
    }

    func testIsEmptyResponseActualText() {
        XCTAssertFalse(AutopilotService.isEmptyResponse("yes, continue"))
    }

    func testIsEmptyResponseEmptyPrefix() {
        // "EMPTY but not really" is real text, not empty
        XCTAssertFalse(AutopilotService.isEmptyResponse("EMPTY but not really"))
    }
}
