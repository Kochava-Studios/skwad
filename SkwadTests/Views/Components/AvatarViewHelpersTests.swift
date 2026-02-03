import XCTest
import AppKit
import Foundation
@testable import Skwad

final class AvatarViewHelpersTests: XCTestCase {

    // MARK: - Avatar Image Parsing

    /// Helper that mirrors the avatarImage parsing logic from AvatarView
    static func parseAvatarBase64(_ avatar: String) -> Data? {
        guard let commaIndex = avatar.firstIndex(of: ",") else { return nil }
        let base64String = String(avatar[avatar.index(after: commaIndex)...])
        return Data(base64Encoded: base64String)
    }

    /// Check if an avatar string is a valid data URI
    static func isDataURI(_ avatar: String?) -> Bool {
        guard let avatar = avatar else { return false }
        return avatar.hasPrefix("data:image")
    }

    // MARK: - Data URI Detection

    func testDetectsPngDataURI() {
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        XCTAssertTrue(AvatarViewHelpersTests.isDataURI(uri))
    }

    func testDetectsJpegDataURI() {
        let uri = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA=="
        XCTAssertTrue(AvatarViewHelpersTests.isDataURI(uri))
    }

    func testRejectsEmojiString() {
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI("🤖"))
    }

    func testRejectsPlainText() {
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI("hello"))
    }

    func testRejectsNil() {
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI(nil))
    }

    func testRejectsEmptyString() {
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI(""))
    }

    func testRejectsPartialDataPrefix() {
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI("data:"))
        XCTAssertFalse(AvatarViewHelpersTests.isDataURI("data:text"))
    }

    // MARK: - Base64 Parsing

    func testExtractsBase64DataFromValidDataURI() {
        // A 1x1 transparent PNG
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data!.count, 0)
    }

    func testReturnsNilForMissingComma() {
        let uri = "data:image/png;base64"
        let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

        XCTAssertNil(data)
    }

    func testReturnsNilForInvalidBase64() {
        let uri = "data:image/png;base64,not-valid-base64!!!"
        let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

        XCTAssertNil(data)
    }

    func testHandlesEmptyBase64Section() {
        let uri = "data:image/png;base64,"
        let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

        // Empty string is valid base64, returns empty data
        XCTAssertNotNil(data)
        XCTAssertEqual(data!.count, 0)
    }

    func testParsedDataCanCreateNSImage() {
        // A 1x1 red PNG
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

        XCTAssertNotNil(data)
        let image = NSImage(data: data!)
        XCTAssertNotNil(image)
    }
}
