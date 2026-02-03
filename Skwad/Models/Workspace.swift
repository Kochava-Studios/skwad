import Foundation
import SwiftUI

/// Predefined color palette for workspaces
enum WorkspaceColor: String, CaseIterable, Codable {
    case blue = "#1B4FB2"
    case purple = "#7158D4"
    case magenta = "#AA4AB8"
    case lavender = "#C4B8F3"
    case pink = "#EA3E81"
    case rosePink = "#EFA3E6"
    case skyBlue = "#97C8F1"
    case cyan = "#0093FF"
    case aqua = "#66E0FD"
    case lime = "#B3DA59"
    case green = "#46A857"
    case teal = "#89B2B0"
    case mauve = "#C28897"
    case coral = "#F29C9D"
    case red = "#E25444"
    case orange = "#F78A47"
    case amber = "#FFB325"
    case tan = "#DEB068"

    var color: Color {
        Color(hex: rawValue) ?? .blue
    }

    static var `default`: WorkspaceColor { .blue }
}

/// A workspace containing a group of agents with its own layout state
struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String  // hex color code from WorkspaceColor
    var agentIds: [UUID]  // ordered list of agents in this workspace

    // Layout state (per-workspace)
    var layoutMode: LayoutMode
    var activeAgentIds: [UUID]  // which agents are visible in panes
    var focusedPaneIndex: Int
    var splitRatio: CGFloat  // primary split ratio (kept for backwards compatibility, maps to splitRatioPrimary)
    var splitRatioSecondary: CGFloat?  // secondary split ratio - optional for backwards compatibility

    /// Primary split ratio (vertical in splitVertical/grid, horizontal in splitHorizontal)
    var splitRatioPrimary: CGFloat {
        get { splitRatio }
        set { splitRatio = newValue }
    }

    /// Secondary split ratio with default fallback (used in grid mode)
    var effectiveSplitRatioSecondary: CGFloat {
        splitRatioSecondary ?? 0.5
    }

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = WorkspaceColor.default.rawValue,
        agentIds: [UUID] = [],
        layoutMode: LayoutMode = .single,
        activeAgentIds: [UUID] = [],
        focusedPaneIndex: Int = 0,
        splitRatio: CGFloat = 0.5,
        splitRatioSecondary: CGFloat? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.agentIds = agentIds
        self.layoutMode = layoutMode
        self.activeAgentIds = activeAgentIds
        self.focusedPaneIndex = focusedPaneIndex
        self.splitRatio = splitRatio
        self.splitRatioSecondary = splitRatioSecondary
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    /// Get initial(s) for avatar display (1-2 uppercase characters)
    var initials: String {
        Self.computeInitials(from: name)
    }

    /// Compute initials from a name string (shared utility)
    static func computeInitials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(separator: " ")
        if words.count >= 2 {
            // First letter of first two words
            let first = words[0].prefix(1).uppercased()
            let second = words[1].prefix(1).uppercased()
            return first + second
        } else {
            // First 1-2 characters of single word
            return String(trimmed.prefix(2)).uppercased()
        }
    }

    /// Create the default "Skwad" workspace
    static func createDefault(withAgentIds agentIds: [UUID] = []) -> Workspace {
        Workspace(
            name: "Skwad",
            colorHex: WorkspaceColor.blue.rawValue,
            agentIds: agentIds,
            activeAgentIds: agentIds.isEmpty ? [] : [agentIds[0]]
        )
    }
}

