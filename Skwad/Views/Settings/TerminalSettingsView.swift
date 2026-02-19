import SwiftUI

struct TerminalSettingsView: View {
  @ObservedObject private var settings = AppSettings.shared

  @State private var backgroundColor: Color
  @State private var foregroundColor: Color

  private let terminalEngines = [
    ("ghostty", "Ghostty (GPU-accelerated)"),
    ("swiftterm", "SwiftTerm")
  ]

  private let monospaceFonts = [
    "SF Mono",
    "Menlo",
    "Monaco",
    "Courier New",
    "Andale Mono",
    "JetBrains Mono",
    "Fira Code",
    "Source Code Pro",
    "IBM Plex Mono",
    "Hack",
    "Inconsolata"
  ]

  private var availableFonts: [String] {
    let fontManager = NSFontManager.shared
    let allFonts = fontManager.availableFontFamilies
    return monospaceFonts.filter { allFonts.contains($0) }
  }

  init() {
    let s = AppSettings.shared
    _backgroundColor = State(initialValue: s.terminalBackgroundColor)
    _foregroundColor = State(initialValue: s.terminalForegroundColor)
  }

  var body: some View {
    Form {
      Section {
        Picker("Engine", selection: $settings.terminalEngine) {
          ForEach(terminalEngines, id: \.0) { engine in
            Text(engine.1).tag(engine.0)
          }
        }
      } header: {
        Text("Terminal Engine")
      } footer: {
        Text("Changing terminal engine requires restarting Skwad.")
          .foregroundColor(.secondary)
      }

      if settings.terminalEngine == "ghostty" {
        ghosttySettings
      } else {
        swiftTermSettings
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .padding()
  }

  @ViewBuilder
  private var ghosttySettings: some View {
    Section {
      HStack {
        Text("Configuration")
        Spacer()
        Text(settings.ghosttyConfigPath)
          .foregroundColor(.secondary)
          .font(.system(.body, design: .monospaced))
      }

      if settings.ghosttyBackgroundColor != nil {
        HStack {
          Text("Background color")
          Spacer()
          RoundedRectangle(cornerRadius: 4)
            .fill(settings.effectiveBackgroundColor)
            .frame(width: 24, height: 24)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
      }
    } header: {
      Text("Ghostty")
    } footer: {
      Text("Font, colors, and theme are loaded from your Ghostty configuration file.")
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private var swiftTermSettings: some View {
    Section {
      Picker("Font", selection: $settings.terminalFontName) {
        ForEach(availableFonts, id: \.self) { font in
          Text(font)
            .font(.custom(font, size: 13))
            .tag(font)
        }
      }

      HStack {
        Text("Size")
        Spacer()
        Slider(value: $settings.terminalFontSize, in: 9...24, step: 1) {
          Text("Size")
        }
        .frame(width: 150)
        Text("\(Int(settings.terminalFontSize)) pt")
          .monospacedDigit()
          .frame(width: 45, alignment: .trailing)
      }
    } header: {
      Text("Font")
    }

    Section {
      ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
        .onChange(of: backgroundColor) { _, newValue in
          settings.terminalBackgroundColor = newValue
        }

      ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: false)
        .onChange(of: foregroundColor) { _, newValue in
          settings.terminalForegroundColor = newValue
        }
    } header: {
      Text("Colors")
    }

    Section {
      TerminalPreviewView()
        .frame(height: 80)
    } header: {
      Text("Preview")
    }
  }
}

struct TerminalPreviewView: View {
  @ObservedObject private var settings = AppSettings.shared

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 8)
        .fill(settings.terminalBackgroundColor)

      VStack(alignment: .leading, spacing: 4) {
        Text("$ claude")
        Text("Agent started...")
        Text("~/Projects/my-app")
      }
      .font(.custom(settings.terminalFontName, size: settings.terminalFontSize))
      .foregroundColor(settings.terminalForegroundColor)
      .padding(12)
    }
  }
}
