import XCTest
import SwiftUI
@testable import Skwad

final class ContentViewHelpersTests: XCTestCase {

    // MARK: - Single Mode Layout

    func testSingleModeReturnsFullSize() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 0,
            layoutMode: .single,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin, .zero)
        XCTAssertEqual(rect.size, size)
    }

    func testSingleModeIgnoresPaneIndex() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = ContentView.computePaneRect(pane: 0, layoutMode: .single, splitRatio: 0.5, splitRatioSecondary: 0.5, in: size)
        let rect1 = ContentView.computePaneRect(pane: 1, layoutMode: .single, splitRatio: 0.5, splitRatioSecondary: 0.5, in: size)

        XCTAssertEqual(rect0, rect1)
    }

    // MARK: - Split Vertical Layout

    func testSplitVerticalPane0IsLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 0,
            layoutMode: .splitVertical,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 800)
    }

    func testSplitVerticalPane1IsRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 1,
            layoutMode: .splitVertical,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 800)
    }

    func testSplitVerticalRespectsSplitRatio() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = ContentView.computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.3, splitRatioSecondary: 0.5, in: size)
        let rect1 = ContentView.computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.3, splitRatioSecondary: 0.5, in: size)

        XCTAssertEqual(rect0.width, 300)
        XCTAssertEqual(rect1.width, 700)
        XCTAssertEqual(rect1.origin.x, 300)
    }

    func testSplitVerticalPanesCoverFullWidth() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = ContentView.computePaneRect(pane: 0, layoutMode: .splitVertical, splitRatio: 0.6, splitRatioSecondary: 0.5, in: size)
        let rect1 = ContentView.computePaneRect(pane: 1, layoutMode: .splitVertical, splitRatio: 0.6, splitRatioSecondary: 0.5, in: size)

        XCTAssertEqual(rect0.width + rect1.width, size.width)
    }

    // MARK: - Split Horizontal Layout

    func testSplitHorizontalPane0IsTop() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 0,
            layoutMode: .splitHorizontal,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 1000)
        XCTAssertEqual(rect.height, 400)
    }

    func testSplitHorizontalPane1IsBottom() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 1,
            layoutMode: .splitHorizontal,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 1000)
        XCTAssertEqual(rect.height, 400)
    }

    func testSplitHorizontalRespectsSplitRatio() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = ContentView.computePaneRect(pane: 0, layoutMode: .splitHorizontal, splitRatio: 0.25, splitRatioSecondary: 0.5, in: size)
        let rect1 = ContentView.computePaneRect(pane: 1, layoutMode: .splitHorizontal, splitRatio: 0.25, splitRatioSecondary: 0.5, in: size)

        XCTAssertEqual(rect0.height, 200)
        XCTAssertEqual(rect1.height, 600)
        XCTAssertEqual(rect1.origin.y, 200)
    }

    // MARK: - Grid Four Pane Layout

    func testGridPane0IsTopLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 0,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane1IsTopRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 1,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane2IsBottomLeft() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 2,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridPane3IsBottomRight() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 3,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin.x, 500)
        XCTAssertEqual(rect.origin.y, 400)
        XCTAssertEqual(rect.width, 500)
        XCTAssertEqual(rect.height, 400)
    }

    func testGridInvalidPaneReturnsFullSize() {
        let size = CGSize(width: 1000, height: 800)
        let rect = ContentView.computePaneRect(
            pane: 5,
            layoutMode: .gridFourPane,
            splitRatio: 0.5,
            splitRatioSecondary: 0.5,
            in: size
        )

        XCTAssertEqual(rect.origin, .zero)
        XCTAssertEqual(rect.size, size)
    }

    func testGridPanesCoverFullArea() {
        let size = CGSize(width: 1000, height: 800)
        var totalArea: CGFloat = 0

        for pane in 0..<4 {
            let rect = ContentView.computePaneRect(
                pane: pane,
                layoutMode: .gridFourPane,
                splitRatio: 0.5,
                splitRatioSecondary: 0.5,
                in: size
            )
            totalArea += rect.width * rect.height
        }

        XCTAssertEqual(totalArea, size.width * size.height)
    }

    func testGridWithDifferentRatios() {
        let size = CGSize(width: 1000, height: 800)
        let rect0 = ContentView.computePaneRect(pane: 0, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, in: size)
        let rect1 = ContentView.computePaneRect(pane: 1, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, in: size)
        let rect2 = ContentView.computePaneRect(pane: 2, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, in: size)
        let rect3 = ContentView.computePaneRect(pane: 3, layoutMode: .gridFourPane, splitRatio: 0.3, splitRatioSecondary: 0.6, in: size)

        XCTAssertEqual(rect0.width, 300)
        XCTAssertEqual(rect1.width, 700)
        XCTAssertEqual(rect2.width, 300)
        XCTAssertEqual(rect3.width, 700)

        XCTAssertEqual(rect0.height, 480)
        XCTAssertEqual(rect1.height, 480)
        XCTAssertEqual(rect2.height, 320)
        XCTAssertEqual(rect3.height, 320)

        XCTAssertEqual(rect0.origin, CGPoint(x: 0, y: 0))
        XCTAssertEqual(rect1.origin, CGPoint(x: 300, y: 0))
        XCTAssertEqual(rect2.origin, CGPoint(x: 0, y: 480))
        XCTAssertEqual(rect3.origin, CGPoint(x: 300, y: 480))
    }

    func testGridPanesCoverFullAreaWithDifferentRatios() {
        let size = CGSize(width: 1000, height: 800)
        var totalArea: CGFloat = 0

        for pane in 0..<4 {
            let rect = ContentView.computePaneRect(
                pane: pane,
                layoutMode: .gridFourPane,
                splitRatio: 0.4,
                splitRatioSecondary: 0.7,
                in: size
            )
            totalArea += rect.width * rect.height
        }

        XCTAssertEqual(totalArea, size.width * size.height)
    }

    // MARK: - Layout Mode Codable

    func testLayoutModesAreCodable() throws {
        let modes: [LayoutMode] = [.single, .splitVertical, .splitHorizontal, .threePane, .gridFourPane]

        for mode in modes {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(LayoutMode.self, from: encoded)
            XCTAssertEqual(decoded, mode)
        }
    }
}
