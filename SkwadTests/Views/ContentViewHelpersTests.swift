import XCTest
import SwiftUI
@testable import Skwad

final class ContentViewHelpersTests: XCTestCase {

    // MARK: - Pane Layout Computation

    /// Test helper that mirrors the computePaneRect logic from ContentView
    private func computePaneRect(pane: Int, layoutMode: LayoutMode, splitRatio: CGFloat, splitRatioSecondary: CGFloat = 0.5, size: CGSize) -> CGRect {
        switch layoutMode {
        case .single:
            return CGRect(origin: .zero, size: size)
        case .splitVertical:  // left | right
            let w0 = size.width * splitRatio
            let w1 = size.width - w0
            return pane == 0
                ? CGRect(x: 0, y: 0, width: w0, height: size.height)
                : CGRect(x: w0, y: 0, width: w1, height: size.height)
        case .splitHorizontal:  // top / bottom
            let h0 = size.height * splitRatio
            let h1 = size.height - h0
            return pane == 0
                ? CGRect(x: 0, y: 0, width: size.width, height: h0)
                : CGRect(x: 0, y: h0, width: size.width, height: h1)
        case .threePane:  // left half full-height | right top / right bottom
            let w0 = size.width * splitRatio
            let w1 = size.width - w0
            let h0 = size.height * splitRatioSecondary
            let h1 = size.height - h0
            switch pane {
            case 0: return CGRect(x: 0, y: 0, width: w0, height: size.height)  // left (full height)
            case 1: return CGRect(x: w0, y: 0, width: w1, height: h0)          // top-right
            case 2: return CGRect(x: w0, y: h0, width: w1, height: h1)         // bottom-right
            default: return CGRect(origin: .zero, size: size)
            }
        case .gridFourPane:  // 4-pane grid (primary = vertical, secondary = horizontal)
            let w0 = size.width * splitRatio
            let w1 = size.width - w0
            let h0 = size.height * splitRatioSecondary
            let h1 = size.height - h0
            switch pane {
            case 0: return CGRect(x: 0, y: 0, width: w0, height: h0)        // top-left
            case 1: return CGRect(x: w0, y: 0, width: w1, height: h0)       // top-right
            case 2: return CGRect(x: 0, y: h0, width: w0, height: h1)       // bottom-left
            case 3: return CGRect(x: w0, y: h0, width: w1, height: h1)      // bottom-right
            default: return CGRect(origin: .zero, size: size)
            }
        }
    }

    // MARK: - Single Mode Layout

    func testSingleModeReturnsFullSize() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 0,
            layoutMode: .single,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin, .zero)
        XCTAssertEqual(rect.size, size)
    }

    func testSingleModeIgnoresPaneIndex() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = computePaneRect(pane: 0, layoutMode: .single, splitRatio: 0.5, size: size)
        let rect1 = computePaneRect(pane: 1, layoutMode: .single, splitRatio: 0.5, size: size)

        XCTAssertEqual(rect0, rect1)
    }

    // MARK: - Split Vertical Layout

    func testSplitVerticalPane0IsLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 0,
            layoutMode: .splitVertical,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 800)
    }

    func testSplitVerticalPane1IsRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 1,
            layoutMode: .splitVertical,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 800)
    }

    func testSplitVerticalRespectsSplitRatio() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.3, size: size)
        let rect1 = computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.3, size: size)

        XCTAssertEqual(rect0.width, 300)
        XCTAssertEqual(rect1.width, 700)
        XCTAssertEqual(rect1.origin.x, 300)
    }

    func testSplitVerticalPanesCoverFullWidth() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.6, size: size)
        let rect1 = computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.6, size: size)

        XCTAssertEqual(rect0.width + rect1.width, size.width)
    }

    // MARK: - Split Horizontal Layout

    func testSplitHorizontalPane0IsTop() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 0,
            layoutMode: .splitHorizontal,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 1000)
        XCTAssertEqual(rect.height, 400)
    }

    func testSplitHorizontalPane1IsBottom() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 1,
            layoutMode: .splitHorizontal,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 1000)
        XCTAssertEqual(rect.height, 400)
    }

    func testSplitHorizontalRespectsSplitRatio() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = computePaneRect(pane: 0, layoutMode: .splitHorizontal, splitRatio: 0.25, size: size)
        let rect1 = computePaneRect(pane: 1, layoutMode: .splitHorizontal, splitRatio: 0.25, size: size)

        XCTAssertEqual(rect0.height, 200)
        XCTAssertEqual(rect1.height, 600)
        XCTAssertEqual(rect1.origin.y, 200)
    }

    // MARK: - Grid Four Pane Layout

    func testGridPane0IsTopLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 0,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane1IsTopRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 1,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane2IsBottomLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 2,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane3IsBottomRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 3,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridInvalidPaneReturnsFullSize() {
        let size = CGSize(width: 1000, height: 800)
        let rect = computePaneRect(
            pane: 5,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            size: size
        )

        XCTAssertEqual(rect.origin, .zero)
        XCTAssertEqual(rect.size, size)
    }

    func testGridPanesCoverFullArea() {
        let size = CGSize(width: 1000, height: 800)
        var totalArea: CGFloat = 0

        for pane in 0..<4 {
            let rect = computePaneRect(
                pane: pane,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )
            totalArea += rect.width * rect.height
        }

        XCTAssertEqual(totalArea, size.width * size.height)
    }

    func testGridWithDifferentRatios() {
        let size = CGSize(width: 1000, height: 800)
        // Primary = 0.3 (vertical), Secondary = 0.6 (horizontal)
        let rect0 = computePaneRect(pane: 0, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, size: size)
        let rect1 = computePaneRect(pane: 1, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, size: size)
        let rect2 = computePaneRect(pane: 2, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, size: size)
        let rect3 = computePaneRect(pane: 3, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, size: size)

        // Verify widths: left panes = 300, right panes = 700
        XCTAssertEqual(rect0.width, 300)
        XCTAssertEqual(rect1.width, 700)
        XCTAssertEqual(rect2.width, 300)
        XCTAssertEqual(rect3.width, 700)

        // Verify heights: top panes = 480, bottom panes = 320
        XCTAssertEqual(rect0.height, 480)
        XCTAssertEqual(rect1.height, 480)
        XCTAssertEqual(rect2.height, 320)
        XCTAssertEqual(rect3.height, 320)

        // Verify positions
        XCTAssertEqual(rect0.origin, CGPoint(x: 0, y: 0))
        XCTAssertEqual(rect1.origin, CGPoint(x: 300, y: 0))
        XCTAssertEqual(rect2.origin, CGPoint(x: 0, y: 480))
        XCTAssertEqual(rect3.origin, CGPoint(x: 300, y: 480))
    }

    func testGridPanesCoverFullAreaWithDifferentRatios() {
        let size = CGSize(width: 1000, height: 800)
        var totalArea: CGFloat = 0

        for pane in 0..<4 {
            let rect = computePaneRect(
                pane: pane,
                layoutMode: .gridFourPane,
                splitRatio: 0.4,
                splitRatioSecondary: 0.7,
                size: size
            )
            totalArea += rect.width * rect.height
        }

        XCTAssertEqual(totalArea, size.width * size.height)
    }

    // MARK: - Git Panel Availability

    /// Helper to determine if git panel can be shown
    private func canShowGitPanel(activeAgent: Agent?) -> Bool {
        guard let agent = activeAgent else { return false }
        return GitWorktreeManager.shared.isGitRepo(agent.folder)
    }

    func testCanShowGitPanelReturnsFalseWhenNoAgent() {
        let result = canShowGitPanel(activeAgent: nil)
        XCTAssertFalse(result)
    }

    func testCanShowGitPanelReturnsFalseForNonGitFolder() {
        let agent = Agent(name: "Test", folder: "/tmp")
        let result = canShowGitPanel(activeAgent: agent)
        XCTAssertFalse(result)
    }

    // MARK: - Sidebar Width Constraints

    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 400

    private func constrainSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minSidebarWidth), maxSidebarWidth)
    }

    func testSidebarWidthConstrainedToMinimum() {
        let result = constrainSidebarWidth(100)
        XCTAssertEqual(result, 200)
    }

    func testSidebarWidthConstrainedToMaximum() {
        let result = constrainSidebarWidth(500)
        XCTAssertEqual(result, 400)
    }

    func testSidebarWidthWithinBoundsUnchanged() {
        let result = constrainSidebarWidth(300)
        XCTAssertEqual(result, 300)
    }

    func testSidebarWidthAtMinimumBoundary() {
        let result = constrainSidebarWidth(200)
        XCTAssertEqual(result, 200)
    }

    func testSidebarWidthAtMaximumBoundary() {
        let result = constrainSidebarWidth(400)
        XCTAssertEqual(result, 400)
    }

    // MARK: - Split Ratio Constraints

    private func constrainSplitRatio(_ ratio: CGFloat) -> CGFloat {
        max(0.25, min(0.75, ratio))
    }

    func testSplitRatioConstrainedToMinimum025() {
        let result = constrainSplitRatio(0.1)
        XCTAssertEqual(result, 0.25)
    }

    func testSplitRatioConstrainedToMaximum075() {
        let result = constrainSplitRatio(0.9)
        XCTAssertEqual(result, 0.75)
    }

    func testSplitRatioWithinBoundsUnchanged() {
        let result = constrainSplitRatio(0.5)
        XCTAssertEqual(result, 0.5)
    }

    func testSplitRatioAtBoundaries() {
        XCTAssertEqual(constrainSplitRatio(0.25), 0.25)
        XCTAssertEqual(constrainSplitRatio(0.75), 0.75)
    }

    // MARK: - Layout Mode Detection

    func testSingleModeIsSinglePane() {
        let mode = LayoutMode.single
        XCTAssertEqual(mode, .single)
        XCTAssertEqual(mode.rawValue, "single")
    }

    func testSplitVerticalModeIsLeftRight() {
        let mode = LayoutMode.splitVertical
        XCTAssertEqual(mode, .splitVertical)
        XCTAssertEqual(mode.rawValue, "splitVertical")
    }

    func testSplitHorizontalModeIsTopBottom() {
        let mode = LayoutMode.splitHorizontal
        XCTAssertEqual(mode, .splitHorizontal)
        XCTAssertEqual(mode.rawValue, "splitHorizontal")
    }

    func testGridFourPaneModeIsGrid() {
        let mode = LayoutMode.gridFourPane
        XCTAssertEqual(mode, .gridFourPane)
        XCTAssertEqual(mode.rawValue, "gridFourPane")
    }

    func testLayoutModesAreCodable() throws {
        let modes: [LayoutMode] = [.single, .splitVertical, .splitHorizontal, .threePane, .gridFourPane]

        for mode in modes {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(LayoutMode.self, from: encoded)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - Audio Waveform

    /// Helper to compute bar height from sample value
    private func computeBarHeight(sample: Float, maxHeight: CGFloat) -> CGFloat {
        max(2, CGFloat(sample) * maxHeight)
    }

    func testBarHeightHasMinimumOf2() {
        let height = computeBarHeight(sample: 0, maxHeight: 100)
        XCTAssertEqual(height, 2)
    }

    func testBarHeightScalesWithSample() {
        let height = computeBarHeight(sample: 0.5, maxHeight: 100)
        XCTAssertEqual(height, 50)
    }

    func testBarHeightReachesMaxHeight() {
        let height = computeBarHeight(sample: 1.0, maxHeight: 100)
        XCTAssertEqual(height, 100)
    }

    func testNegativeSampleClampsToMinimum() {
        let height = computeBarHeight(sample: -0.5, maxHeight: 100)
        XCTAssertEqual(height, 2)  // max(2, -50) = 2
    }
}
