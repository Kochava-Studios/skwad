import Testing
import SwiftUI
@testable import Skwad

@Suite("AvatarView")
struct AvatarViewTests {

    // MARK: - Avatar Type Detection (via AvatarUtils)

    @Test("emoji string is not data URI")
    func emojiIsNotDataURI() {
        #expect(!AvatarUtils.isDataURI("🤖"))
    }

    @Test("PNG data URI is detected")
    func pngDataURIIsDetected() {
        #expect(AvatarUtils.isDataURI("data:image/png;base64,iVBORw0KGgo="))
    }

    @Test("JPEG data URI is detected")
    func jpegDataURIIsDetected() {
        #expect(AvatarUtils.isDataURI("data:image/jpeg;base64,/9j/4AAQ="))
    }

    @Test("nil avatar is not data URI")
    func nilIsNotDataURI() {
        #expect(!AvatarUtils.isDataURI(nil))
    }

    @Test("empty avatar is not data URI")
    func emptyIsNotDataURI() {
        #expect(!AvatarUtils.isDataURI(""))
    }

    // MARK: - Base64 Parsing (via AvatarUtils)

    @Test("valid base64 data URI parses correctly")
    func validBase64Parses() {
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let data = AvatarUtils.parseBase64Data(uri)
        #expect(data != nil)
        #expect(data!.count > 0)
    }

    @Test("invalid base64 returns nil")
    func invalidBase64ReturnsNil() {
        let data = AvatarUtils.parseBase64Data("data:image/png;base64,not-valid!!!")
        #expect(data == nil)
    }

    @Test("parseImage returns NSImage for valid data")
    func parseImageReturnsImage() {
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        #expect(AvatarUtils.parseImage(uri) != nil)
    }
}
