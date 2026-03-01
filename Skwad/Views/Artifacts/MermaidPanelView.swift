import SwiftUI
import BeautifulMermaid

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

    private var theme: DiagramTheme {
        colorScheme == .dark ? .zincDark : .zincLight
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

            Image(systemName: "chart.dots.scatter")
                .foregroundColor(.secondary)

            Text(title ?? "Diagram")
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

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

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let error = renderError {
            errorView(error)
        } else if let image = renderedImage {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
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
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let image = try MermaidRenderer.renderImage(
                    source: source,
                    theme: currentTheme,
                    scale: 2.0
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
