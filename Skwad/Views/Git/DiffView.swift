import SwiftUI

/// Displays a file diff with syntax highlighting
struct DiffView: View {
    let diff: FileDiff

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if diff.isBinary {
                    binaryFileView
                } else if diff.hunks.isEmpty {
                    emptyDiffView
                } else {
                    ForEach(diff.hunks) { hunk in
                        HunkView(hunk: hunk)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.primary.opacity(0.05))
    }

    private var binaryFileView: some View {
        HStack {
            Image(systemName: "doc.fill")
            Text("Binary file")
        }
        .foregroundColor(.secondary)
        .padding()
    }

    private var emptyDiffView: some View {
        Text("No changes")
            .foregroundColor(.secondary)
            .padding()
    }
}

/// Displays a single hunk of changes
struct HunkView: View {
    let hunk: DiffHunk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hunk.lines) { line in
                DiffLineView(line: line)
            }
        }
    }
}

/// Displays a single line in the diff
struct DiffLineView: View {
    let line: DiffLine

    private var backgroundColor: Color {
        switch line.kind {
        case .addition:
            return Color.green.opacity(0.2)
        case .deletion:
            return Color.red.opacity(0.2)
        case .hunkHeader:
            return Color.blue.opacity(0.15)
        case .context, .header:
            return .clear
        }
    }

    private var textColor: Color {
        switch line.kind {
        case .addition:
            return Color.green
        case .deletion:
            return Color.red
        case .hunkHeader:
            return Color.blue
        case .context, .header:
            return Color.primary.opacity(0.8)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers
            HStack(spacing: 0) {
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundColor(.gray.opacity(0.6))

                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .foregroundColor(.gray.opacity(0.6))
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.trailing, 8)

            // Content
            Text(line.kind.prefix + line.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }
}

// MARK: - Preview

#Preview {
    DiffView(diff: FileDiff(
        path: "test.swift",
        oldPath: nil,
        isBinary: false,
        hunks: [
            DiffHunk(
                header: "@@ -1,5 +1,7 @@",
                oldStart: 1,
                oldCount: 5,
                newStart: 1,
                newCount: 7,
                lines: [
                    DiffLine(kind: .hunkHeader, content: "@@ -1,5 +1,7 @@", oldLineNumber: nil, newLineNumber: nil),
                    DiffLine(kind: .context, content: "import Foundation", oldLineNumber: 1, newLineNumber: 1),
                    DiffLine(kind: .deletion, content: "let old = true", oldLineNumber: 2, newLineNumber: nil),
                    DiffLine(kind: .addition, content: "let new = true", oldLineNumber: nil, newLineNumber: 2),
                    DiffLine(kind: .addition, content: "let another = false", oldLineNumber: nil, newLineNumber: 3),
                    DiffLine(kind: .context, content: "", oldLineNumber: 3, newLineNumber: 4),
                ]
            )
        ]
    ))
    .frame(width: 500, height: 300)
}
