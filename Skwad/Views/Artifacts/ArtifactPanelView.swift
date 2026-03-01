import SwiftUI

/// Container panel for agent artifacts (markdown, mermaid diagrams).
/// Owns the resize handle, panel width, and expand/collapse.
/// When both sections are active, a draggable divider sits between them
/// and each section's header gains a collapse chevron.
struct ArtifactPanelView: View {

    let agent: Agent
    @Binding var isExpanded: Bool
    let onCloseMarkdown: () -> Void
    let onCloseMermaid: () -> Void
    let onMarkdownComment: (String) -> Void
    let onMarkdownSubmitReview: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @State private var panelWidth: CGFloat = 500
    @State private var markdownCollapsed = false
    @State private var mermaidCollapsed = false
    @State private var splitRatio: CGFloat = 0.5
    @State private var dragStartRatio: CGFloat?

    private var hasMarkdown: Bool { agent.markdownFilePath != nil }
    private var hasMermaid: Bool { agent.mermaidSource != nil }
    private var hasBoth: Bool { hasMarkdown && hasMermaid }

    private var backgroundColor: Color {
        settings.effectiveBackgroundColor
    }

    var body: some View {
        HStack(spacing: 0) {
            if !isExpanded {
                resizeHandle
            }

            VStack(spacing: 0) {
                panelToolbar

                Divider()
                    .background(Color.primary.opacity(0.2))

                // Sections
                GeometryReader { geo in
                    if hasBoth {
                        dualSectionLayout(totalHeight: geo.size.height)
                    } else {
                        singleSectionLayout
                    }
                }
            }
            .frame(width: isExpanded ? nil : panelWidth)
        }
        .frame(maxWidth: isExpanded ? .infinity : nil)
        .background(backgroundColor)
    }

    // MARK: - Single Section Layout

    /// When only one section is active, show it full height with expand/close in its own header
    @ViewBuilder
    private var singleSectionLayout: some View {
        if hasMarkdown, let filePath = agent.markdownFilePath {
            VStack(spacing: 0) {
                MarkdownPanelView(
                    filePath: filePath,
                    agentId: agent.id,
                    isCollapsed: .constant(false),
                    onClose: onCloseMarkdown,
                    onComment: onMarkdownComment,
                    onSubmitReview: onMarkdownSubmitReview
                )
            }
        } else if hasMermaid, let source = agent.mermaidSource {
            VStack(spacing: 0) {
                MermaidPanelView(
                    source: source,
                    title: agent.mermaidTitle,
                    isCollapsed: .constant(false),
                    onClose: onCloseMermaid
                )
            }
        }
    }

    // MARK: - Dual Section Layout

    private func dualSectionLayout(totalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Markdown section
            if let filePath = agent.markdownFilePath {
                MarkdownPanelView(
                    filePath: filePath,
                    agentId: agent.id,
                    isCollapsible: true,
                    isCollapsed: $markdownCollapsed,
                    onClose: onCloseMarkdown,
                    onComment: onMarkdownComment,
                    onSubmitReview: onMarkdownSubmitReview
                )
                .frame(height: sectionHeight(for: .markdown, totalHeight: totalHeight))
                .clipped()
            }

            // Divider between sections (only when both have content visible)
            if !markdownCollapsed && !mermaidCollapsed {
                sectionDivider(totalHeight: totalHeight)
            }

            // Mermaid section
            if let source = agent.mermaidSource {
                MermaidPanelView(
                    source: source,
                    title: agent.mermaidTitle,
                    isCollapsible: true,
                    isCollapsed: $mermaidCollapsed,
                    onClose: onCloseMermaid
                )
                .frame(height: sectionHeight(for: .mermaid, totalHeight: totalHeight))
                .clipped()
            }
        }
    }

    // MARK: - Panel Toolbar

    private var panelToolbar: some View {
        HStack {
            Text("Artifacts")
                .font(.title3.weight(.medium))
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse panel" : "Expand panel")

            Button {
                onCloseMarkdown()
                onCloseMermaid()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close all")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Section Divider

    private func sectionDivider(totalHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(height: 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = splitRatio
                        }
                        let newRatio = dragStartRatio! + value.translation.height / totalHeight
                        splitRatio = max(0.15, min(0.85, newRatio))
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
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

    // MARK: - Layout Helpers

    private enum Section { case markdown, mermaid }

    private static let collapsedSectionHeight: CGFloat = 34

    private func sectionHeight(for section: Section, totalHeight: CGFloat) -> CGFloat {
        let headerHeight = Self.collapsedSectionHeight
        let dividerHeight: CGFloat = 4

        // Both collapsed
        if markdownCollapsed && mermaidCollapsed {
            return headerHeight
        }

        // One collapsed, other gets remaining space
        if markdownCollapsed {
            return section == .markdown ? headerHeight : totalHeight - headerHeight
        }
        if mermaidCollapsed {
            return section == .mermaid ? headerHeight : totalHeight - headerHeight
        }

        // Both expanded — split by ratio
        let availableHeight = totalHeight - dividerHeight
        switch section {
        case .markdown:
            return availableHeight * splitRatio
        case .mermaid:
            return availableHeight * (1 - splitRatio)
        }
    }
}
