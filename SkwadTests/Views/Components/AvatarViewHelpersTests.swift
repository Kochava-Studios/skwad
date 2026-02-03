import Testing
import AppKit
import Foundation
@testable import Skwad

@Suite("AvatarView Helpers")
struct AvatarViewHelpersTests {

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

    @Suite("Data URI Detection")
    struct DataURIDetectionTests {

        @Test("detects PNG data URI")
        func detectsPngDataURI() {
            let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
            #expect(AvatarViewHelpersTests.isDataURI(uri) == true)
        }

        @Test("detects JPEG data URI")
        func detectsJpegDataURI() {
            let uri = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA=="
            #expect(AvatarViewHelpersTests.isDataURI(uri) == true)
        }

        @Test("rejects emoji string")
        func rejectsEmojiString() {
            #expect(AvatarViewHelpersTests.isDataURI("🤖") == false)
        }

        @Test("rejects plain text")
        func rejectsPlainText() {
            #expect(AvatarViewHelpersTests.isDataURI("hello") == false)
        }

        @Test("rejects nil")
        func rejectsNil() {
            #expect(AvatarViewHelpersTests.isDataURI(nil) == false)
        }

        @Test("rejects empty string")
        func rejectsEmptyString() {
            #expect(AvatarViewHelpersTests.isDataURI("") == false)
        }

        @Test("rejects partial data prefix")
        func rejectsPartialDataPrefix() {
            #expect(AvatarViewHelpersTests.isDataURI("data:") == false)
            #expect(AvatarViewHelpersTests.isDataURI("data:text") == false)
        }
    }

    @Suite("Base64 Parsing")
    struct Base64ParsingTests {

        @Test("extracts base64 data from valid data URI")
        func extractsBase64FromValidURI() {
            // A 1x1 transparent PNG
            let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
            let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

            #expect(data != nil)
            #expect(data!.count > 0)
        }

        @Test("returns nil for missing comma")
        func returnsNilForMissingComma() {
            let uri = "data:image/png;base64"
            let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

            #expect(data == nil)
        }

        @Test("returns nil for invalid base64")
        func returnsNilForInvalidBase64() {
            let uri = "data:image/png;base64,not-valid-base64!!!"
            let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

            #expect(data == nil)
        }

        @Test("handles empty base64 section")
        func handlesEmptyBase64Section() {
            let uri = "data:image/png;base64,"
            let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

            // Empty string is valid base64, returns empty data
            #expect(data != nil)
            #expect(data!.count == 0)
        }

        @Test("parsed data can create NSImage")
        func parsedDataCreatesNSImage() {
            // A 1x1 red PNG
            let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
            let data = AvatarViewHelpersTests.parseAvatarBase64(uri)

            #expect(data != nil)
            let image = NSImage(data: data!)
            #expect(image != nil)
        }
    }
}
