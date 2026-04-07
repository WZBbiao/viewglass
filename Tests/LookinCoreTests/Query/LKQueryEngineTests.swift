import XCTest
@testable import LookinCore

final class LKQueryEngineTests: XCTestCase {
    let engine = LKQueryEngine()
    let snapshot = MockHierarchyService.makeSampleSnapshot()

    func testQueryByClassName() throws {
        let results = try engine.execute(expression: "UIButton", on: snapshot)
        XCTAssertEqual(results.count, 2) // button + hiddenButton
        XCTAssertTrue(results.allSatisfy { $0.className == "UIButton" })
    }

    func testQueryByClassPrefix() throws {
        let results = try engine.execute(expression: "UI*", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount) // All nodes are UI*
    }

    func testQueryByClassSuffix() throws {
        let results = try engine.execute(expression: "*Label", on: snapshot)
        XCTAssertEqual(results.count, 2)
    }

    func testQueryByOid() throws {
        let results = try engine.execute(expression: "oid:4", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].className, "UIButton")
    }

    func testQueryByTag() throws {
        let results = try engine.execute(expression: "tag:0", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount) // All have tag=0
    }

    func testQueryByDepth() throws {
        let results = try engine.execute(expression: "depth:0", on: snapshot)
        XCTAssertEqual(results.count, 1) // Only window
        XCTAssertEqual(results[0].className, "UIWindow")
    }

    func testQueryVisible() throws {
        let results = try engine.execute(expression: ".visible", on: snapshot)
        XCTAssertTrue(results.allSatisfy(\.isVisible))
    }

    func testQueryHidden() throws {
        let results = try engine.execute(expression: ".hidden", on: snapshot)
        XCTAssertTrue(results.allSatisfy { !$0.isVisible })
        XCTAssertGreaterThan(results.count, 0)
    }

    func testQueryInteractive() throws {
        let results = try engine.execute(expression: ".interactive", on: snapshot)
        XCTAssertTrue(results.allSatisfy(\.isUserInteractionEnabled))
    }

    func testQueryByAccessibilityLabel() throws {
        let results = try engine.execute(expression: "@\"Tap me\"", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].className, "UILabel")
    }

    func testQueryAND() throws {
        let results = try engine.execute(expression: "UIButton AND .visible", on: snapshot)
        // Only the visible UIButton (not the hidden one)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].isVisible)
    }

    func testQueryOR() throws {
        let results = try engine.execute(expression: "UIWindow OR UILabel", on: snapshot)
        XCTAssertEqual(results.count, 3) // 1 window + 2 labels
    }

    func testQueryNOT() throws {
        let results = try engine.execute(expression: "NOT UIView", on: snapshot)
        XCTAssertTrue(results.allSatisfy { $0.className != "UIView" })
    }

    func testQueryByClass() throws {
        let results = try engine.execute(expression: "class:UILabel", on: snapshot)
        XCTAssertEqual(results.count, 2)
    }

    func testQueryByParent() throws {
        let results = try engine.execute(expression: "parent:UIButton", on: snapshot)
        XCTAssertEqual(results.count, 1) // buttonLabel
        XCTAssertEqual(results[0].className, "UILabel")
    }

    func testQueryEmptyExpression() {
        XCTAssertThrowsError(try engine.execute(expression: "", on: snapshot))
    }

    func testQueryInvalidExpression() {
        XCTAssertThrowsError(try engine.execute(expression: "invalid_lower", on: snapshot))
    }

    func testQueryComplexExpression() throws {
        let results = try engine.execute(
            expression: "(UIButton OR UILabel) AND .visible",
            on: snapshot
        )
        // visible UIButton (1) + visible UILabels (2)
        XCTAssertEqual(results.count, 3)
    }
}
