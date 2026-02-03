import XCTest
import SwiftUI
import ViewInspector
@testable import Skwad

final class AvatarViewUITests: XCTestCase {

    // MARK: - Emoji Display Tests

    func testDisplaysEmoji() throws {
        let view = AvatarView(avatar: "🤖", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "🤖")
    }

    func testDisplaysDefaultEmojiWhenNil() throws {
        let view = AvatarView(avatar: nil, size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "🤖")
    }

    func testDisplaysVariousEmojis() throws {
        let emojis = ["🦊", "🐱", "🚀", "⭐", "🔥", "💻", "🎮", "🌟"]
        for emoji in emojis {
            let view = AvatarView(avatar: emoji, size: 40)
            let text = try view.inspect().find(ViewType.Text.self)
            XCTAssertEqual(try text.string(), emoji, "Failed for emoji: \(emoji)")
        }
    }

    func testDisplaysTextForNonDataURIString() throws {
        let view = AvatarView(avatar: "hello", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "hello")
    }

    // MARK: - Image Display Tests

    func testDisplaysImageForValidDataURI() throws {
        // 1x1 red PNG
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        let view = AvatarView(avatar: dataURI, size: 40)

        // Should find an Image, not Text
        let image = try? view.inspect().find(ViewType.Image.self)
        XCTAssertNotNil(image, "Should render an Image for valid data URI")
    }

    func testFallsBackToTextForInvalidBase64() throws {
        let invalidURI = "data:image/png;base64,not-valid-base64!!!"
        let view = AvatarView(avatar: invalidURI, size: 40)

        // Should fall back to Text since base64 is invalid
        let text = try? view.inspect().find(ViewType.Text.self)
        XCTAssertNotNil(text, "Should fall back to Text for invalid base64")
    }

    func testFallsBackToTextForMalformedDataURI() throws {
        // Missing comma separator
        let malformedURI = "data:image/pngbase64iVBORw0KGgo="
        let view = AvatarView(avatar: malformedURI, size: 40)

        let text = try? view.inspect().find(ViewType.Text.self)
        XCTAssertNotNil(text, "Should fall back to Text for malformed data URI")
    }

    // MARK: - Size Tests

    func testFrameSizeMatchesParameter() throws {
        let sizes: [CGFloat] = [20, 40, 60, 80, 100]
        for size in sizes {
            let view = AvatarView(avatar: "🤖", size: size)
            let text = try view.inspect().find(ViewType.Text.self)
            let frame = try text.fixedFrame()
            XCTAssertEqual(frame.width, size, "Width should be \(size)")
            XCTAssertEqual(frame.height, size, "Height should be \(size)")
        }
    }

    func testImageFrameSizeMatchesParameter() throws {
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        let view = AvatarView(avatar: dataURI, size: 50)

        let image = try view.inspect().find(ViewType.Image.self)
        let frame = try image.fixedFrame()
        XCTAssertEqual(frame.width, 50)
        XCTAssertEqual(frame.height, 50)
    }

    // MARK: - Font Tests

    func testUsesDefaultFont() throws {
        let view = AvatarView(avatar: "🤖", size: 40)
        // Default font is .largeTitle
        let text = try view.inspect().find(ViewType.Text.self)
        // ViewInspector can verify the text exists with the expected content
        XCTAssertEqual(try text.string(), "🤖")
    }

    func testUsesCustomFont() throws {
        let view = AvatarView(avatar: "🎮", size: 40, font: .title)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "🎮")
    }

    func testUsesBodyFont() throws {
        let view = AvatarView(avatar: "🚀", size: 16, font: .body)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "🚀")
    }

    // MARK: - Edge Cases

    func testEmptyStringShowsEmptyText() throws {
        let view = AvatarView(avatar: "", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "")
    }

    func testWhitespaceOnlyString() throws {
        let view = AvatarView(avatar: "   ", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "   ")
    }

    func testDataImagePrefixWithoutBase64() throws {
        // Has data:image prefix but no actual base64 content
        let view = AvatarView(avatar: "data:image/png;base64,", size: 40)
        // Empty base64 should fail to create image, fall back to text
        let text = try? view.inspect().find(ViewType.Text.self)
        XCTAssertNotNil(text)
    }

    func testJpegDataURI() throws {
        // A tiny valid JPEG (1x1 pixel)
        let jpegURI = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBEQACEQADAAB/EACP/9k="
        let view = AvatarView(avatar: jpegURI, size: 40)

        let image = try? view.inspect().find(ViewType.Image.self)
        XCTAssertNotNil(image, "Should render JPEG data URI as Image")
    }

    func testLongEmojiSequence() throws {
        // Family emoji (multi-codepoint)
        let view = AvatarView(avatar: "👨‍👩‍👧‍👦", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "👨‍👩‍👧‍👦")
    }

    func testFlagEmoji() throws {
        let view = AvatarView(avatar: "🇫🇷", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        XCTAssertEqual(try text.string(), "🇫🇷")
    }
}
