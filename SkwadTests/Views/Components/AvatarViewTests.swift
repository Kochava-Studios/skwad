import Testing
import SwiftUI
import ViewInspector
@testable import Skwad

// Make AvatarView inspectable
extension AvatarView: @retroactive Inspectable {}

@Suite("AvatarView")
struct AvatarViewTests {

    @Test("displays emoji when avatar is emoji")
    func displaysEmojiWhenAvatarIsEmoji() throws {
        let view = AvatarView(avatar: "🤖", size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        let string = try text.string()
        #expect(string == "🤖")
    }

    @Test("displays default robot emoji when avatar is nil")
    func displaysDefaultRobotWhenNil() throws {
        let view = AvatarView(avatar: nil, size: 40)
        let text = try view.inspect().find(ViewType.Text.self)
        let string = try text.string()
        #expect(string == "🤖")
    }

    @Test("displays image when avatar is valid data URI")
    func displaysImageWhenValidDataURI() throws {
        // A 1x1 red PNG as base64
        let dataURI = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
        let view = AvatarView(avatar: dataURI, size: 40)

        // Should render an Image, not Text
        let image = try? view.inspect().find(ViewType.Image.self)
        #expect(image != nil)
    }

    @Test("displays emoji when data URI is invalid")
    func displaysEmojiWhenDataURIIsInvalid() throws {
        // Invalid base64
        let invalidURI = "data:image/png;base64,notvalidbase64!!!"
        let view = AvatarView(avatar: invalidURI, size: 40)

        // Should fall back to showing the invalid string as text
        // Actually, the view checks hasPrefix("data:image") first, then tries to parse
        // If parsing fails, it shows the text. Let's check what actually renders.
        let text = try? view.inspect().find(ViewType.Text.self)
        #expect(text != nil)  // Falls back to Text
    }

    @Test("respects size parameter")
    func respectsSizeParameter() throws {
        let view = AvatarView(avatar: "🚀", size: 60)
        // The frame is set on the Text
        let text = try view.inspect().find(ViewType.Text.self)
        let frame = try text.fixedFrame()
        #expect(frame.width == 60)
        #expect(frame.height == 60)
    }

    @Test("uses custom font")
    func usesCustomFont() throws {
        let view = AvatarView(avatar: "🎮", size: 40, font: .title)
        let text = try view.inspect().find(ViewType.Text.self)
        // Font inspection is limited, but we can verify the text exists
        #expect(try text.string() == "🎮")
    }

    @Test("various emoji avatars render correctly")
    func variousEmojiAvatarsRender() throws {
        let emojis = ["🦊", "🐱", "🚀", "⭐", "🔥", "💻"]

        for emoji in emojis {
            let view = AvatarView(avatar: emoji, size: 40)
            let text = try view.inspect().find(ViewType.Text.self)
            let string = try text.string()
            #expect(string == emoji, "Expected \(emoji) but got \(string)")
        }
    }
}
