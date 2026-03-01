import SwiftUI
import BeautifulMermaid

/// Available mermaid themes with display names
enum MermaidThemeOption: String, CaseIterable {
    case auto = "auto"
    case catppuccinLatte = "catppuccinLatte"
    case catppuccinMocha = "catppuccinMocha"
    case dracula = "dracula"
    case githubDark = "githubDark"
    case githubLight = "githubLight"
    case nord = "nord"
    case nordLight = "nordLight"
    case oneDark = "oneDark"
    case solarizedDark = "solarizedDark"
    case solarizedLight = "solarizedLight"
    case tokyoNight = "tokyoNight"
    case tokyoNightLight = "tokyoNightLight"
    case tokyoNightStorm = "tokyoNightStorm"
    case zincDark = "zincDark"
    case zincLight = "zincLight"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .catppuccinLatte: return "Catppuccin Latte"
        case .catppuccinMocha: return "Catppuccin Mocha"
        case .dracula: return "Dracula"
        case .githubDark: return "GitHub Dark"
        case .githubLight: return "GitHub Light"
        case .nord: return "Nord"
        case .nordLight: return "Nord Light"
        case .oneDark: return "One Dark"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        case .tokyoNight: return "Tokyo Night"
        case .tokyoNightLight: return "Tokyo Night Light"
        case .tokyoNightStorm: return "Tokyo Night Storm"
        case .zincDark: return "Zinc Dark"
        case .zincLight: return "Zinc Light"
        }
    }

    func diagramTheme(backgroundColor: Color, isDark: Bool) -> DiagramTheme {
        switch self {
        case .auto:
            let base: DiagramTheme = isDark ? .zincDark : .zincLight
            return base.withBackground(NSColor(backgroundColor))
        case .catppuccinLatte: return .catppuccinLatte
        case .catppuccinMocha: return .catppuccinMocha
        case .dracula: return .dracula
        case .githubDark: return .githubDark
        case .githubLight: return .githubLight
        case .nord: return .nord
        case .nordLight: return .nordLight
        case .oneDark: return .oneDark
        case .solarizedDark: return .solarizedDark
        case .solarizedLight: return .solarizedLight
        case .tokyoNight: return .tokyoNight
        case .tokyoNightLight: return .tokyoNightLight
        case .tokyoNightStorm: return .tokyoNightStorm
        case .zincDark: return .zincDark
        case .zincLight: return .zincLight
        }
    }
}

/// Mermaid section content for the artifact panel
struct MermaidPanelView: View {
    let source: String
    let title: String?
    var isCollapsible: Bool = false
    @Binding var isCollapsed: Bool
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared
    @SwiftUI.State private var renderedImage: NSImage?
    @SwiftUI.State private var renderError: String?
    @SwiftUI.State private var zoomLevel: CGFloat = 1.0
    @SwiftUI.State private var showThemePicker = false

    private var selectedTheme: MermaidThemeOption {
        MermaidThemeOption(rawValue: settings.mermaidTheme) ?? .auto
    }

    private var theme: DiagramTheme {
        selectedTheme.diagramTheme(backgroundColor: backgroundColor, isDark: colorScheme == .dark)
    }

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                Divider()
                    .background(Color.primary.opacity(0.2))

                contentView
            }
        }
        .background(backgroundColor)
        .onAppear { renderDiagram() }
        .onChange(of: source) { _, _ in renderDiagram() }
        .onChange(of: colorScheme) { _, _ in renderDiagram() }
        .onChange(of: settings.mermaidTheme) { _, _ in renderDiagram() }
        .onChange(of: settings.mermaidScale) { _, _ in renderDiagram() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Clickable title to collapse/expand
            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Text(title ?? "Diagram")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(title ?? "Diagram")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if !isCollapsed {
                // Zoom controls
                HStack(spacing: 4) {
                    Button {
                        zoomLevel = max(0.25, zoomLevel - 0.25)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom out")
                    .disabled(zoomLevel <= 0.25)

                    Button {
                        zoomLevel = min(4.0, zoomLevel + 0.25)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Zoom in")
                    .disabled(zoomLevel >= 4.0)
                }

                // Theme picker
                Button {
                    showThemePicker.toggle()
                } label: {
                    Image(systemName: "paintpalette")
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Theme")
                .popover(isPresented: $showThemePicker, arrowEdge: .bottom) {
                    themePickerContent
                }
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCollapsible ? 8 : 12)
        .background(Color.primary.opacity(0.05))
    }

    // MARK: - Theme Picker

    private var themePickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Theme")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(MermaidThemeOption.allCases, id: \.rawValue) { option in
                        Button {
                            settings.mermaidTheme = option.rawValue
                            showThemePicker = false
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if option == selectedTheme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(option == selectedTheme ? Color.primary.opacity(0.08) : Color.clear)
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 200)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let error = renderError {
            errorView(error)
        } else if let image = renderedImage {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .interpolation(.high)
                    .frame(
                        width: image.size.width * zoomLevel,
                        height: image.size.height * zoomLevel
                    )
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Failed to render diagram")
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rendering

    private func renderDiagram() {
        renderedImage = nil
        renderError = nil

        let currentTheme = theme
        let scale = settings.mermaidScale
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let image = try MermaidRenderer.renderImage(
                    source: source,
                    theme: currentTheme,
                    scale: scale
                )
                DispatchQueue.main.async {
                    renderedImage = image
                }
            } catch {
                DispatchQueue.main.async {
                    renderError = error.localizedDescription
                }
            }
        }
    }
}

#Preview("Mermaid Panel") {
    MermaidPanelView(
        source: """
        graph TD
            A[Start] --> B{Decision}
            B -->|Yes| C[Do Something]
            B -->|No| D[Do Something Else]
            C --> E[End]
            D --> E
        """,
        title: "Flow Diagram",
        isCollapsed: .constant(false),
        onClose: {}
    )
    .frame(width: 500, height: 400)
}
