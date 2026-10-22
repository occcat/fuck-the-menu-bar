import XCTest
@testable import Overlay
import SharedUI

final class ShelfBubbleMetricsTests: XCTestCase {
    func testVisibleRowCountIsClamped() {
        XCTAssertEqual(ShelfBubbleMetrics.visibleRowCount(for: 0), 1)
        XCTAssertEqual(ShelfBubbleMetrics.visibleRowCount(for: 3), 3)
        XCTAssertEqual(ShelfBubbleMetrics.visibleRowCount(for: 12), ShelfBubbleMetrics.maxVisibleRows)
    }

    func testBubbleHeightMatchesDrawnRowGeometry() {
        let expected =
            3 * ShelfBubbleMetrics.rowHeight +
            2 * ShelfBubbleMetrics.rowSpacing +
            2 * ShelfBubbleMetrics.panelPadding
        XCTAssertEqual(ShelfBubbleMetrics.bubbleHeight(itemCount: 3), expected, accuracy: 0.001)
    }

    func testBubbleStopsGrowingAndScrollsBeyondMaxRows() {
        let maxRows = ShelfBubbleMetrics.maxVisibleRows
        XCTAssertEqual(
            ShelfBubbleMetrics.bubbleHeight(itemCount: maxRows + 7),
            ShelfBubbleMetrics.bubbleHeight(itemCount: maxRows),
            accuracy: 0.001
        )
        XCTAssertFalse(ShelfBubbleMetrics.needsScrolling(itemCount: maxRows))
        XCTAssertTrue(ShelfBubbleMetrics.needsScrolling(itemCount: maxRows + 1))
    }

    func testCornerRadiiAreConcentric() {
        XCTAssertEqual(
            ShelfBubbleMetrics.rowCornerRadius + ShelfBubbleMetrics.panelPadding,
            ShelfBubbleMetrics.bubbleCornerRadius,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(ShelfBubbleMetrics.iconTileCornerRadius, 0)
        XCTAssertLessThan(ShelfBubbleMetrics.iconTileCornerRadius, ShelfBubbleMetrics.rowCornerRadius)
    }

    func testMotionDurationIsClampedAndSettleOutlastsSpring() {
        XCTAssertEqual(LiquidMotion.duration(base: 0.01), 0.2, accuracy: 0.0001)
        XCTAssertEqual(LiquidMotion.duration(base: 5), 0.7, accuracy: 0.0001)
        XCTAssertGreaterThan(
            LiquidMotion.settleDuration(base: 0.18, reduceMotion: false),
            LiquidMotion.duration(base: 0.18)
        )
        XCTAssertLessThan(LiquidMotion.settleDuration(base: 0.6, reduceMotion: true), 0.2)
    }
}
