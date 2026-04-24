import XCTest
import CoreGraphics
@testable import LookinCLI
@testable import LookinCore

final class ActionSupportTests: XCTestCase {
    func testParseCGPointAcceptsCommaSeparatedPair() throws {
        let point = try parseCGPoint(argument: "12,34", label: "scroll")
        XCTAssertEqual(point.x, 12)
        XCTAssertEqual(point.y, 34)
    }

    func testParseCGPointRejectsInvalidInput() {
        XCTAssertThrowsError(try parseCGPoint(argument: "12", label: "scroll")) { error in
            guard case LookinCoreError.actionFailed(let action, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(action, "scroll")
        }
    }

    func testParseCGSizeAcceptsNSSizeString() throws {
        let size = try parseCGSize(argument: "NSSize: {390, 1280}", label: "contentSize")
        XCTAssertEqual(size.width, 390)
        XCTAssertEqual(size.height, 1280)
    }

    func testParseCGRectAcceptsNSRectString() throws {
        let rect = try parseCGRect(argument: "NSRect: {{0, 0}, {390, 721}}", label: "bounds")
        XCTAssertEqual(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 390)
        XCTAssertEqual(rect.height, 721)
    }

    func testParseScrollInsetsAcceptsUIEdgeInsetsString() throws {
        let insets = try parseScrollInsets(argument: "UIEdgeInsets: {0, 0, 78, 0}", label: "adjustedContentInset")
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.left, 0)
        XCTAssertEqual(insets.bottom, 78)
        XCTAssertEqual(insets.right, 0)
    }

    func testScrollMetricsClampUsesContentSizeViewportAndInsets() {
        let metrics = ScrollMetrics(
            contentOffset: .zero,
            contentSize: CGSize(width: 390, height: 805),
            viewportSize: CGSize(width: 390, height: 721),
            adjustedContentInset: ScrollInsets(top: 0, left: 0, bottom: 78, right: 0)
        )

        let clamped = metrics.clampedOffset(CGPoint(x: 0, y: 600))
        XCTAssertEqual(clamped.x, 0)
        XCTAssertEqual(clamped.y, 162)
    }
}
