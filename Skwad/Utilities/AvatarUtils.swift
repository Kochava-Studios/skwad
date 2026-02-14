import AppKit

enum AvatarUtils {

    /// Check if an avatar string is a data URI (e.g. "data:image/png;base64,...")
    static func isDataURI(_ avatar: String?) -> Bool {
        guard let avatar = avatar else { return false }
        return avatar.hasPrefix("data:image")
    }

    /// Extract base64-encoded image data from a data URI string
    static func parseBase64Data(_ avatar: String) -> Data? {
        guard let commaIndex = avatar.firstIndex(of: ",") else { return nil }
        let base64String = String(avatar[avatar.index(after: commaIndex)...])
        return Data(base64Encoded: base64String)
    }

    /// Parse a data URI avatar string into an NSImage
    static func parseImage(_ avatar: String) -> NSImage? {
        guard let data = parseBase64Data(avatar) else { return nil }
        return NSImage(data: data)
    }
}
