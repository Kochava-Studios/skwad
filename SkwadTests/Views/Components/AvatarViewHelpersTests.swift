import XCTest
import AppKit
import Foundation
@testable import Skwad

final class AvatarViewHelpersTests: XCTestCase {

    // MARK: - Data URI Detection

    func testDetectsPngDataURI() {
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        XCTAssertTrue(AvatarUtils.isDataURI(uri))
    }

    func testDetectsJpegDataURI() {
        let uri = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA=="
        XCTAssertTrue(AvatarUtils.isDataURI(uri))
    }

    func testRejectsEmojiString() {
        XCTAssertFalse(AvatarUtils.isDataURI("🤖"))
    }

    func testRejectsPlainText() {
        XCTAssertFalse(AvatarUtils.isDataURI("hello"))
    }

    func testRejectsNil() {
        XCTAssertFalse(AvatarUtils.isDataURI(nil))
    }

    func testRejectsEmptyString() {
        XCTAssertFalse(AvatarUtils.isDataURI(""))
    }

    func testRejectsPartialDataPrefix() {
        XCTAssertFalse(AvatarUtils.isDataURI("data:"))
        XCTAssertFalse(AvatarUtils.isDataURI("data:text"))
    }

    // MARK: - Base64 Parsing

    func testExtractsBase64DataFromValidDataURI() {
        // A 1x1 transparent PNG
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let data = AvatarUtils.parseBase64Data(uri)

        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 0)
    }

    func testReturnsNilForMissingComma() {
        let uri = "data:image/png;base64"
        let data = AvatarUtils.parseBase64Data(uri)

        XCTAssertNil(data)
    }

    func testReturnsNilForInvalidBase64() {
        let uri = "data:image/png;base64,not-valid-base64!!!"
        let data = AvatarUtils.parseBase64Data(uri)

        XCTAssertNil(data)
    }

    func testHandlesEmptyBase64Section() {
        let uri = "data:image/png;base64,"
        let data = AvatarUtils.parseBase64Data(uri)

        // Empty string is valid base64, returns empty data
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.count, 0)
    }

    func testParsedDataCanCreateNSImage() {
        // A 1x1 red PNG
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        let image = AvatarUtils.parseImage(uri)

        XCTAssertNotNil(image)
    }
}
