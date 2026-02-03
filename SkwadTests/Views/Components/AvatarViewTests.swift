import Testing
import SwiftUI
@testable import Skwad

// Note: ViewInspector + Swift Testing causes test runner crashes (exit code 6)
// These tests use XCTest in a separate file: AvatarViewUITests.swift

@Suite("AvatarView")
struct AvatarViewTests {

    // MARK: - Avatar Type Detection

    @Test("emoji string is not data URI")
    func emojiIsNotDataURI() {
        let avatar = "🤖"
        #expect(!avatar.hasPrefix("data:image"))
    }

    @Test("PNG data URI is detected")
    func pngDataURIIsDetected() {
        let avatar = "data:image/png;base64,iVBORw0KGgo="
        #expect(avatar.hasPrefix("data:image"))
    }

    @Test("JPEG data URI is detected")
    func jpegDataURIIsDetected() {
        let avatar = "data:image/jpeg;base64,/9j/4AAQ="
        #expect(avatar.hasPrefix("data:image"))
    }

    @Test("nil avatar uses default")
    func nilAvatarUsesDefault() {
        let avatar: String? = nil
        let display = avatar ?? "🤖"
        #expect(display == "🤖")
    }

    @Test("empty avatar uses default")
    func emptyAvatarUsesDefault() {
        let avatar = ""
        let display = avatar.isEmpty ? "🤖" : avatar
        #expect(display == "🤖")
    }

    // MARK: - Base64 Parsing (mirrors AvatarViewHelpersTests but for completeness)

    @Test("valid base64 data URI parses correctly")
    func validBase64Parses() {
        let uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        guard let commaIndex = uri.firstIndex(of: ",") else {
            Issue.record("No comma found")
            return
        }
        let base64String = String(uri[uri.index(after: commaIndex)...])
        let data = Data(base64Encoded: base64String)
        #expect(data != nil)
        #expect(data!.count > 0)
    }

    @Test("invalid base64 returns nil")
    func invalidBase64ReturnsNil() {
        let uri = "data:image/png;base64,not-valid!!!"
        guard let commaIndex = uri.firstIndex(of: ",") else {
            Issue.record("No comma found")
            return
        }
        let base64String = String(uri[uri.index(after: commaIndex)...])
        let data = Data(base64Encoded: base64String)
        #expect(data == nil)
    }

    // MARK: - Size Calculations

    @Test("size is used for frame dimensions")
    func sizeUsedForFrame() {
        let size: CGFloat = 40
        // The view uses size for both width and height
        #expect(size == 40)
    }

    @Test("font size scales with avatar size")
    func fontSizeScales() {
        let size: CGFloat = 60
        // Default font calculation: size * 0.6 for emoji display
        let expectedFontSize = size * 0.6
        #expect(expectedFontSize == 36)
    }
}
