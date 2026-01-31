import SwiftUI

enum Theme {
    // Text colors - use semantic colors that adapt to light/dark mode
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    // Selection - purple accent works in both modes
    static let selectionBackground = Color(hex: "#4A90E2")!.opacity(0.25)
    static let selectionBorder = Color(hex: "#4A90E2")!
}
