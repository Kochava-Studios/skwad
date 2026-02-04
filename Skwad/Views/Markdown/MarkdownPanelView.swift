import SwiftUI
import MarkdownUI

/// Sliding panel showing markdown content for a file
struct MarkdownPanelView: View {
    let filePath: String
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared
    @State private var panelWidth: CGFloat = 500
    @State private var content: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle

            VStack(spacing: 0) {
                header

                Divider()
                    .background(Color.primary.opacity(0.2))

                contentView
            }
            .frame(width: panelWidth)
        }
        .background(backgroundColor)
        .onAppear {
            loadContent()
        }
        .onChange(of: filePath) { _, _ in
            loadContent()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if let markdown = content {
            ScrollView {
                Markdown(markdown)
                    .markdownTheme(.basic)
                    .markdownTextStyle { FontSize(15) }
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(backgroundColor)
            }
            .scrollContentBackground(.hidden)
            .background(backgroundColor)
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newWidth = panelWidth - value.translation.width
                        panelWidth = max(350, min(800, newWidth))
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)

            Text(fileName)
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
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
    }

    // MARK: - States

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load Content

    private func loadContent() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check file exists
                guard FileManager.default.fileExists(atPath: filePath) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "File not found:\n\(filePath)"
                        self.isLoading = false
                    }
                    return
                }

                // Check it's readable
                guard FileManager.default.isReadableFile(atPath: filePath) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Cannot read file:\n\(filePath)"
                        self.isLoading = false
                    }
                    return
                }

                // Read content
                let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)

                DispatchQueue.main.async {
                    self.content = fileContent
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to read file:\n\(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview("Markdown Panel") {
    MarkdownPanelView(
        filePath: "/Users/nbonamy/src/skwad/README.md",
        onClose: {}
    )
    .frame(height: 600)
}
