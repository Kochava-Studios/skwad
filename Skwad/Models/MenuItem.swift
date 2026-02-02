import SwiftUI

/// Represents an "Open With" application option
struct OpenWithApp: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String?      // Asset image name
    let systemIcon: String? // SF Symbol fallback

    init(_ id: String, _ name: String, icon: String? = nil, systemIcon: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemIcon = systemIcon
    }

    static func == (lhs: OpenWithApp, rhs: OpenWithApp) -> Bool {
        lhs.id == rhs.id
    }
}

/// Generic menu item that can be either an app or separator
enum MenuElement: Identifiable {
    case app(OpenWithApp)
    case separator

    var id: String {
        switch self {
        case .app(let app):
            return app.id
        case .separator:
            return "separator-\(UUID().uuidString)"
        }
    }
}
