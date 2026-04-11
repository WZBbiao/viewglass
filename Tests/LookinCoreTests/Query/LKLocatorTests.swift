import XCTest
@testable import LookinCore

final class LKLocatorTests: XCTestCase {

    // MARK: - Routing to .query for logical expressions

    func testANDExpressionRoutesToQuery() {
        let loc = LKLocator.parse("UILabel AND .visible")
        XCTAssertEqual(loc.kind, .query)
        XCTAssertEqual(loc.value, "UILabel AND .visible")
    }

    func testORExpressionRoutesToQuery() {
        let loc = LKLocator.parse("UIButton OR UILabel")
        XCTAssertEqual(loc.kind, .query)
    }

    func testNOTExpressionRoutesToQuery() {
        let loc = LKLocator.parse("NOT UIButton")
        XCTAssertEqual(loc.kind, .query)
    }

    func testParenExpressionRoutesToQuery() {
        let loc = LKLocator.parse("(UIButton OR UILabel) AND .visible")
        XCTAssertEqual(loc.kind, .query)
    }

    // MARK: - Routing to .accessibilityLabel for plain multi-word strings

    func testPlainMultiWordStringRoutesToAccessibilityLabel() {
        let loc = LKLocator.parse("Open Long Feed")
        XCTAssertEqual(loc.kind, .accessibilityLabel)
        XCTAssertEqual(loc.value, "Open Long Feed")
    }

    func testQuotedAtLabelRoutesToAccessibilityLabel() {
        let loc = LKLocator.parse("@\"Feed card 1\"")
        XCTAssertEqual(loc.kind, .accessibilityLabel)
        XCTAssertEqual(loc.value, "Feed card 1")
    }

    // MARK: - Single-token routing

    func testHashRoutesToAccessibilityIdentifier() {
        let loc = LKLocator.parse("#switch_tab_feed")
        XCTAssertEqual(loc.kind, .accessibilityIdentifier)
        XCTAssertEqual(loc.value, "switch_tab_feed")
    }

    func testClassNameRoutesToQuery() {
        let loc = LKLocator.parse("UILabel")
        XCTAssertEqual(loc.kind, .query)
    }

    func testWildcardRoutesToQuery() {
        let loc = LKLocator.parse("UITab*")
        XCTAssertEqual(loc.kind, .query)
    }

    func testDotVisibleRoutesToQuery() {
        let loc = LKLocator.parse(".visible")
        XCTAssertEqual(loc.kind, .query)
    }

    func testContainsWithQuotedStringRoutesToQuery() {
        let loc = LKLocator.parse("contains:\"Feed card\"")
        XCTAssertEqual(loc.kind, .query)
        XCTAssertEqual(loc.value, "contains:\"Feed card\"")
    }

    func testContainsUnquotedRoutesToQuery() {
        let loc = LKLocator.parse("contains:hello")
        XCTAssertEqual(loc.kind, .query)
    }
}
