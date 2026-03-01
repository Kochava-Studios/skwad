import Testing
import SwiftUI
@testable import Skwad

@Suite("ArtifactPanelView Layout")
struct ArtifactPanelLayoutTests {

    let totalHeight: CGFloat = 600

    // MARK: - Both Expanded

    @Test("both expanded at 50/50 splits evenly minus divider")
    func bothExpandedEvenSplit() {
        let mdHeight = ArtifactPanelView.sectionHeight(
            for: .markdown, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: false, mermaidCollapsed: false
        )
        let mmHeight = ArtifactPanelView.sectionHeight(
            for: .mermaid, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: false, mermaidCollapsed: false
        )
        let available = totalHeight - ArtifactPanelView.dividerHeight

        #expect(mdHeight == available * 0.5)
        #expect(mmHeight == available * 0.5)
        #expect(mdHeight + mmHeight + ArtifactPanelView.dividerHeight == totalHeight)
    }

    @Test("both expanded respects split ratio")
    func bothExpandedRespectsSplitRatio() {
        let mdHeight = ArtifactPanelView.sectionHeight(
            for: .markdown, totalHeight: totalHeight, splitRatio: 0.7,
            markdownCollapsed: false, mermaidCollapsed: false
        )
        let mmHeight = ArtifactPanelView.sectionHeight(
            for: .mermaid, totalHeight: totalHeight, splitRatio: 0.7,
            markdownCollapsed: false, mermaidCollapsed: false
        )

        #expect(mdHeight > mmHeight)
        #expect(abs(mdHeight + mmHeight + ArtifactPanelView.dividerHeight - totalHeight) < 0.01)
    }

    @Test("both expanded heights sum to total")
    func bothExpandedSumToTotal() {
        for ratio in [0.15, 0.3, 0.5, 0.7, 0.85] {
            let md = ArtifactPanelView.sectionHeight(
                for: .markdown, totalHeight: totalHeight, splitRatio: ratio,
                markdownCollapsed: false, mermaidCollapsed: false
            )
            let mm = ArtifactPanelView.sectionHeight(
                for: .mermaid, totalHeight: totalHeight, splitRatio: ratio,
                markdownCollapsed: false, mermaidCollapsed: false
            )
            #expect(md + mm + ArtifactPanelView.dividerHeight == totalHeight)
        }
    }

    // MARK: - Markdown Collapsed

    @Test("markdown collapsed returns header height")
    func markdownCollapsedReturnsHeaderHeight() {
        let height = ArtifactPanelView.sectionHeight(
            for: .markdown, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: true, mermaidCollapsed: false
        )
        #expect(height == ArtifactPanelView.collapsedSectionHeight)
    }

    @Test("mermaid gets remaining space when markdown collapsed")
    func mermaidGetsRemainingWhenMarkdownCollapsed() {
        let height = ArtifactPanelView.sectionHeight(
            for: .mermaid, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: true, mermaidCollapsed: false
        )
        #expect(height == totalHeight - ArtifactPanelView.collapsedSectionHeight)
    }

    // MARK: - Mermaid Collapsed

    @Test("mermaid collapsed returns header height")
    func mermaidCollapsedReturnsHeaderHeight() {
        let height = ArtifactPanelView.sectionHeight(
            for: .mermaid, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: false, mermaidCollapsed: true
        )
        #expect(height == ArtifactPanelView.collapsedSectionHeight)
    }

    @Test("markdown gets remaining space when mermaid collapsed")
    func markdownGetsRemainingWhenMermaidCollapsed() {
        let height = ArtifactPanelView.sectionHeight(
            for: .markdown, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: false, mermaidCollapsed: true
        )
        #expect(height == totalHeight - ArtifactPanelView.collapsedSectionHeight)
    }

    // MARK: - Both Collapsed

    @Test("both collapsed returns header height for both")
    func bothCollapsedReturnsHeaderHeight() {
        let md = ArtifactPanelView.sectionHeight(
            for: .markdown, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: true, mermaidCollapsed: true
        )
        let mm = ArtifactPanelView.sectionHeight(
            for: .mermaid, totalHeight: totalHeight, splitRatio: 0.5,
            markdownCollapsed: true, mermaidCollapsed: true
        )
        #expect(md == ArtifactPanelView.collapsedSectionHeight)
        #expect(mm == ArtifactPanelView.collapsedSectionHeight)
    }
}
