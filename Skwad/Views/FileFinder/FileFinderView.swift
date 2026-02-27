import SwiftUI
import AppKit

struct FileFinderView: View {
    let folder: String
    let onDismiss: () -> Void
    let onSelect: (String) -> Void

    @State private var searchService: FileSearchService = FileSearchService()
    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var debounceTask: Task<Void, Never>?

    private let settings = AppSettings.shared

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))

                    FocusableTextField(
                        text: $query,
                        placeholder: "Search files...",
                        onSubmit: { selectCurrent() },
                        onEscape: { onDismiss() },
                        onArrowUp: { moveSelection(-1) },
                        onArrowDown: { moveSelection(1) }
                    )
                    .font(.system(size: 18))

                    if searchService.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 18, height: 18)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Results list
                if searchService.tooManyFiles && query.isEmpty {
                    Divider()

                    emptyState(icon: "exclamationmark.triangle", text: "Too many files (50,000+ limit)")
                } else if !query.isEmpty && searchService.results.isEmpty && !searchService.isLoading {
                    Divider()
                    emptyState(icon: "magnifyingglass", text: "No matching files")
                } else if !searchService.results.isEmpty {
                    Divider()

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(searchService.results.enumerated()), id: \.element.id) { index, result in
                                    FileResultRow(
                                        result: result,
                                        isSelected: index == selectedIndex
                                    )
                                    .id(result.id)
                                    .onTapGesture {
                                        onSelect(result.relativePath)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 450)
                        .onChange(of: selectedIndex) { _, newIndex in
                            guard newIndex < searchService.results.count else { return }
                            proxy.scrollTo(searchService.results[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .background(settings.effectiveBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .frame(width: 650)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: query) { _, newQuery in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await searchService.search(pattern: newQuery)
                await MainActor.run { selectedIndex = 0 }
            }
        }
        .task {
            await searchService.loadFiles(in: folder)
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func moveSelection(_ delta: Int) {
        let count = searchService.results.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    private func selectCurrent() {
        guard !searchService.results.isEmpty,
              selectedIndex < searchService.results.count else { return }
        onSelect(searchService.results[selectedIndex].relativePath)
    }

    @ViewBuilder
    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - NSTextField wrapper that holds focus against terminal

private struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 18)
        field.delegate = context.coordinator

        // Grab focus aggressively after a short delay (lets the view settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Re-grab focus if terminal stole it
        if nsView.window?.firstResponder !== nsView.currentEditor() {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            return false
        }
    }
}

// MARK: - Result Row

struct FileResultRow: View {
    let result: FileResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: fileIcon(for: result.relativePath))
                .foregroundColor(.secondary)
                .font(.system(size: 14))
                .frame(width: 22)

            highlightedText
                .font(.system(size: 13, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Theme.selectionBackground : Color.clear)
        .contentShape(Rectangle())
    }

    private var highlightedText: some View {
        let chars = Array(result.relativePath)
        let matchSet = Set(result.matchedIndices)

        var text = AttributedString()
        for (i, char) in chars.enumerated() {
            var attrChar = AttributedString(String(char))
            if matchSet.contains(i) {
                attrChar.foregroundColor = .accentColor
                attrChar.font = .system(size: 13, weight: .bold, design: .monospaced)
            } else {
                attrChar.foregroundColor = Theme.primaryText
            }
            text.append(attrChar)
        }
        return Text(text)
    }

    private func fileIcon(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "curlybraces"
        case "json": return "curlybraces.square"
        case "md", "txt", "rtf": return "doc.text"
        case "html", "htm", "xml": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "less": return "paintbrush"
        case "py": return "terminal"
        case "rb": return "diamond"
        case "rs": return "gearshape"
        case "go": return "arrow.right.circle"
        case "sh", "bash", "zsh": return "terminal"
        case "yml", "yaml", "toml": return "list.bullet"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "mp3", "wav", "aac": return "waveform"
        case "mp4", "mov", "avi": return "film"
        case "zip", "tar", "gz": return "archivebox"
        case "lock": return "lock"
        default: return "doc"
        }
    }
}

// MARK: - Previews

private struct FileFinderPreview: View {
    let results: [FileResult]
    let tooManyFiles: Bool
    let query: String
    let selectedIndex: Int

    private let settings = AppSettings.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))

                    Text(query.isEmpty ? "Search files..." : query)
                        .font(.system(size: 18))
                        .foregroundColor(query.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if tooManyFiles && query.isEmpty {
                    Divider()
                    emptyState(icon: "exclamationmark.triangle", text: "Too many files (50,000+ limit)")
                } else if !query.isEmpty && results.isEmpty {
                    Divider()
                    emptyState(icon: "magnifyingglass", text: "No matching files")
                } else if !results.isEmpty {
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                FileResultRow(
                                    result: result,
                                    isSelected: index == selectedIndex
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 450)
                }
            }
            .background(settings.effectiveBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .frame(width: 650)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview("Empty") {
    FileFinderPreview(
        results: [],
        tooManyFiles: false,
        query: "",
        selectedIndex: 0
    )
}

#Preview("No Results") {
    FileFinderPreview(
        results: [],
        tooManyFiles: false,
        query: "xyznotfound",
        selectedIndex: 0
    )
}

#Preview("With Results") {
    FileFinderPreview(
        results: [
            FileResult(relativePath: "Skwad/Views/ContentView.swift", score: 95, matchedIndices: [12, 13, 14, 15, 16, 17, 18]),
            FileResult(relativePath: "Skwad/Views/Sidebar/SidebarView.swift", score: 80, matchedIndices: [12, 13, 14, 15]),
            FileResult(relativePath: "Skwad/Views/Terminal/AgentTerminalView.swift", score: 75, matchedIndices: [12, 13, 14, 15]),
            FileResult(relativePath: "Skwad/Models/Agent.swift", score: 60, matchedIndices: [14, 15, 16, 17, 18]),
            FileResult(relativePath: "Skwad/Services/TerminalAdapter.swift", score: 55, matchedIndices: [9, 10, 11, 12]),
            FileResult(relativePath: "Skwad/Git/GitRepository.swift", score: 40, matchedIndices: [10, 11, 12]),
        ],
        tooManyFiles: false,
        query: "view",
        selectedIndex: 1
    )
}

#Preview("Too Many Files") {
    FileFinderPreview(
        results: [],
        tooManyFiles: true,
        query: "",
        selectedIndex: 0
    )
}
