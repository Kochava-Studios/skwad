import Testing
import SwiftUI
@testable import Skwad

@Suite("ContentView Helpers")
struct ContentViewHelpersTests {

    // MARK: - Pane Layout Computation

    /// Test helper that mirrors the computePaneRect logic from ContentView
    /// This allows testing the pure layout calculation without needing the full view
    static func computePaneRect(pane: Int, layoutMode: LayoutMode, splitRatio: CGFloat, size: CGSize) -> CGRect {
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
        case .gridFourPane:  // 4-pane grid
            let w = size.width / 2
            let h = size.height / 2
            switch pane {
            case 0: return CGRect(x: 0, y: 0, width: w, height: h)        // top-left
            case 1: return CGRect(x: w, y: 0, width: w, height: h)        // top-right
            case 2: return CGRect(x: 0, y: h, width: w, height: h)        // bottom-left
            case 3: return CGRect(x: w, y: h, width: w, height: h)        // bottom-right
            default: return CGRect(origin: .zero, size: size)
            }
        }
    }

    @Suite("Single Mode Layout")
    struct SingleModeLayoutTests {

        @Test("single mode returns full size")
        func singleModeReturnsFullSize() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 0,
                layoutMode: .single,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin == .zero)
            #expect(rect.size == size)
        }

        @Test("single mode ignores pane index")
        func singleModeIgnoresPaneIndex() {
            let size = CGSize(width: 1000, height: 800)
            let rect0 = ContentViewHelpersTests.computePaneRect(pane: 0, layoutMode: .single, splitRatio: 0.5, size: size)
            let rect1 = ContentViewHelpersTests.computePaneRect(pane: 1, layoutMode: .single, splitRatio: 0.5, size: size)

            #expect(rect0 == rect1)
        }
    }

    @Suite("Split Vertical Layout")
    struct SplitVerticalLayoutTests {

        @Test("split vertical pane 0 is left side")
        func splitVerticalPane0IsLeft() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 0,
                layoutMode: .splitVertical,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 500)
            #expect(rect.height == 800)
        }

        @Test("split vertical pane 1 is right side")
        func splitVerticalPane1IsRight() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 1,
                layoutMode: .splitVertical,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 500)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 500)
            #expect(rect.height == 800)
        }

        @Test("split vertical respects split ratio")
        func splitVerticalRespectsRatio() {
            let size = CGSize(width: 1000, height: 800)
            let rect0 = ContentViewHelpersTests.computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.3, size: size)
            let rect1 = ContentViewHelpersTests.computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.3, size: size)

            #expect(rect0.width == 300)
            #expect(rect1.width == 700)
            #expect(rect1.origin.x == 300)
        }

        @Test("split vertical panes cover full width")
        func splitVerticalPanesCoverFullWidth() {
            let size = CGSize(width: 1000, height: 800)
            let rect0 = ContentViewHelpersTests.computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.6, size: size)
            let rect1 = ContentViewHelpersTests.computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.6, size: size)

            #expect(rect0.width + rect1.width == size.width)
        }
    }

    @Suite("Split Horizontal Layout")
    struct SplitHorizontalLayoutTests {

        @Test("split horizontal pane 0 is top")
        func splitHorizontalPane0IsTop() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 0,
                layoutMode: .splitHorizontal,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 1000)
            #expect(rect.height == 400)
        }

        @Test("split horizontal pane 1 is bottom")
        func splitHorizontalPane1IsBottom() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 1,
                layoutMode: .splitHorizontal,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 400)
            #expect(rect.width == 1000)
            #expect(rect.height == 400)
        }

        @Test("split horizontal respects split ratio")
        func splitHorizontalRespectsRatio() {
            let size = CGSize(width: 1000, height: 800)
            let rect0 = ContentViewHelpersTests.computePaneRect(pane: 0, layoutMode: .splitHorizontal, splitRatio: 0.25, size: size)
            let rect1 = ContentViewHelpersTests.computePaneRect(pane: 1, layoutMode: .splitHorizontal, splitRatio: 0.25, size: size)

            #expect(rect0.height == 200)
            #expect(rect1.height == 600)
            #expect(rect1.origin.y == 200)
        }
    }

    @Suite("Grid Four Pane Layout")
    struct GridFourPaneLayoutTests {

        @Test("grid pane 0 is top-left")
        func gridPane0IsTopLeft() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 0,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 500)
            #expect(rect.height == 400)
        }

        @Test("grid pane 1 is top-right")
        func gridPane1IsTopRight() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 1,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 500)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 500)
            #expect(rect.height == 400)
        }

        @Test("grid pane 2 is bottom-left")
        func gridPane2IsBottomLeft() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 2,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 400)
            #expect(rect.width == 500)
            #expect(rect.height == 400)
        }

        @Test("grid pane 3 is bottom-right")
        func gridPane3IsBottomRight() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 3,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin.x == 500)
            #expect(rect.origin.y == 400)
            #expect(rect.width == 500)
            #expect(rect.height == 400)
        }

        @Test("grid invalid pane returns full size")
        func gridInvalidPaneReturnsFullSize() {
            let size = CGSize(width: 1000, height: 800)
            let rect = ContentViewHelpersTests.computePaneRect(
                pane: 5,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                size: size
            )

            #expect(rect.origin == .zero)
            #expect(rect.size == size)
        }

        @Test("grid panes cover full area")
        func gridPanesCoverFullArea() {
            let size = CGSize(width: 1000, height: 800)
            var totalArea: CGFloat = 0

            for pane in 0..<4 {
                let rect = ContentViewHelpersTests.computePaneRect(
                    pane: pane,
                    layoutMode: .gridFourPane,
                    splitRatio: 0.5,
                    size: size
                )
                totalArea += rect.width * rect.height
            }

            #expect(totalArea == size.width * size.height)
        }
    }
}
