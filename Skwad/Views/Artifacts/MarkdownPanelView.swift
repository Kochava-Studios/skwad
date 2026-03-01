import SwiftUI

/// Markdown section content for the artifact panel
struct MarkdownPanelView: View {

    enum ReviewState {
        case viewing     // passive reading — no comment popup on selection
        case reviewing   // review mode active — comment popup on selection
        case submitted   // review sent — hide buttons until file reloads
    }

    let filePath: String
    let agentId: UUID
    var isCollapsible: Bool = false
    @Binding var isCollapsed: Bool
    let onClose: () -> Void
    let onComment: (String) -> Void  // formatted comment text -> inject into terminal
    let onSubmitReview: () -> Void  // send return to submit the prompt

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = AppSettings.shared
    @State private var content: String?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var fileWatcher: FileWatcher?

    // Comment popup state
    @State private var selectedText: String?
    @State private var commentText: String = ""
    @State private var reviewState: ReviewState = .viewing
    @State private var selectionY: CGFloat = 0
    @FocusState private var isCommentFocused: Bool

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    private var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if !isCollapsed {
                Divider()
                    .background(Color.primary.opacity(0.2))

                ZStack(alignment: .topLeading) {
                    contentView

                    if selectedText != nil {
                        commentPopup
                            .offset(y: selectionY + 16)
                            .transition(.opacity)
                    }
                }
            }
        }
        .background(backgroundColor)
        .onAppear {
            loadContent()
            startWatching()
        }
        .onDisappear {
            stopWatching()
        }
        .onChange(of: filePath) { _, _ in
            stopWatching()
            dismissComment()
            loadContent()
            startWatching()
        }
    }

    // MARK: - Content

    private var isReviewActive: Bool {
        reviewState == .reviewing
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading && content == nil {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if let markdown = content {
            MarkdownWebView(
                markdown: markdown,
                fontSize: settings.markdownFontSize,
                backgroundColor: backgroundColor,
                isDarkMode: colorScheme == .dark
            ) { text, y in
                guard isReviewActive else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedText = text
                    commentText = ""
                    selectionY = y
                }
                isCommentFocused = true
            }
        }
    }

    // MARK: - Comment Popup

    private var commentPopup: some View {
        VStack(spacing: 8) {
            // Selected text preview
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(selectedText ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Spacer()
            }

            // Comment text area
            TextEditor(text: $commentText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .frame(height: 60)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .focused($isCommentFocused)
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.command) {
                        submitComment()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        dismissComment()
                    }
                    return .handled
                }

            // Buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        dismissComment()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("Comment") {
                    submitComment()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: -2)
        )
        .padding(.horizontal, 12)
    }

    private func submitComment() {
        guard let selected = selectedText else { return }
        let comment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !comment.isEmpty else { return }

        let text = "- Re \"\(selected)\": \(comment)\n"
        onComment(text)

        withAnimation(.easeInOut(duration: 0.15)) {
            dismissComment()
        }
    }

    private func dismissComment() {
        selectedText = nil
        commentText = ""
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

            if isCollapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Text(fileName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(fileName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            if !isCollapsed {
                switch reviewState {
                case .viewing:
                    Button {
                        onComment("approved let's do it")
                        onSubmitReview()
                        reviewState = .submitted
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Approve and continue")

                    Button {
                        onComment("While reviewing \(fileName), user made the following comments:\n")
                        reviewState = .reviewing
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Review")
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Start reviewing with comments")
                case .reviewing:
                    Button {
                        onSubmitReview()
                        reviewState = .submitted
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "paperplane.fill")
                            Text("Submit Review")
                        }
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Submit review comments to agent")
                case .submitted:
                    EmptyView()
                }

                HStack(spacing: 4) {
                    Button {
                        if settings.markdownFontSize > 10 {
                            settings.markdownFontSize -= 1
                        }
                    } label: {
                        HStack(spacing: 1) {
                            Text("A").font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .frame(height: 24)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Decrease font size")
                    .disabled(settings.markdownFontSize <= 10)

                    Button {
                        if settings.markdownFontSize < 24 {
                            settings.markdownFontSize += 1
                        }
                    } label: {
                        HStack(spacing: 1) {
                            Text("A").font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.up").font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .frame(height: 24)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Increase font size")
                    .disabled(settings.markdownFontSize >= 24)
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
        reviewState = .viewing

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard FileManager.default.fileExists(atPath: filePath) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "File not found:\n\(filePath)"
                        self.isLoading = false
                    }
                    return
                }

                guard FileManager.default.isReadableFile(atPath: filePath) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Cannot read file:\n\(filePath)"
                        self.isLoading = false
                    }
                    return
                }

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

    // MARK: - File Watching

    private func startWatching() {
        fileWatcher = FileWatcher(filePath: filePath) { [self] in
            loadContent()
        }
        fileWatcher?.start()
    }

    private func stopWatching() {
        fileWatcher?.stop()
        fileWatcher = nil
    }
}

#Preview("Markdown Panel") {
    MarkdownPanelView(
        filePath: "/Users/nbonamy/src/skwad/README.md",
        agentId: UUID(),
        isCollapsed: .constant(false),
        onClose: {},
        onComment: { text in
            print("Comment: \(text)")
        },
        onSubmitReview: {
            print("Submit review")
        }
    )
    .frame(height: 600)
}
