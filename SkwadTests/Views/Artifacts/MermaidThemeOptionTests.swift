import Testing
import SwiftUI
@testable import Skwad

@Suite("MermaidThemeOption")
struct MermaidThemeOptionTests {

    // MARK: - Enum Completeness

    @Test("all cases have non-empty display names")
    func allCasesHaveDisplayNames() {
        for option in MermaidThemeOption.allCases {
            #expect(!option.displayName.isEmpty)
        }
    }

    @Test("all cases have non-empty raw values")
    func allCasesHaveRawValues() {
        for option in MermaidThemeOption.allCases {
            #expect(!option.rawValue.isEmpty)
        }
    }

    @Test("allCases starts with auto")
    func allCasesStartsWithAuto() {
        #expect(MermaidThemeOption.allCases.first == .auto)
    }

    @Test("non-auto cases are sorted alphabetically by display name")
    func nonAutoCasesAreSortedAlphabetically() {
        let nonAuto = MermaidThemeOption.allCases.filter { $0 != .auto }
        let displayNames = nonAuto.map { $0.displayName }
        let sorted = displayNames.sorted()
        #expect(displayNames == sorted)
    }

    // MARK: - Raw Value Round-Trip

    @Test("all cases can be initialized from raw value")
    func allCasesRoundTrip() {
        for option in MermaidThemeOption.allCases {
            let roundTripped = MermaidThemeOption(rawValue: option.rawValue)
            #expect(roundTripped == option)
        }
    }

    @Test("invalid raw value returns nil")
    func invalidRawValueReturnsNil() {
        #expect(MermaidThemeOption(rawValue: "nonexistent") == nil)
    }

    // MARK: - Theme Generation

    @Test("auto theme produces a theme in dark mode")
    func autoThemeDarkMode() {
        let theme = MermaidThemeOption.auto.diagramTheme(
            backgroundColor: Color.black,
            isDark: true
        )
        #expect(theme.background != nil)
        #expect(theme.foreground != nil)
    }

    @Test("auto theme produces a theme in light mode")
    func autoThemeLightMode() {
        let theme = MermaidThemeOption.auto.diagramTheme(
            backgroundColor: Color.white,
            isDark: false
        )
        #expect(theme.background != nil)
        #expect(theme.foreground != nil)
    }

    @Test("all non-auto cases produce valid themes")
    func allNonAutoCasesProduceThemes() {
        let nonAuto = MermaidThemeOption.allCases.filter { $0 != .auto }
        for option in nonAuto {
            let theme = option.diagramTheme(backgroundColor: Color.black, isDark: true)
            #expect(theme.background != nil)
            #expect(theme.foreground != nil)
        }
    }
}
