import SwiftUI

enum Theme {
    // Text colors - pure white in dark mode, pure black in light mode
    static let primaryText = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? .white : .black
    }))
    static let secondaryText = primaryText.opacity(0.7)

    // Selection - purple accent works in both modes
    static let selectionBackground = Color(hex: "#4A90E2")!.opacity(0.25)
    static let selectionBorder = Color(hex: "#4A90E2")!
}
