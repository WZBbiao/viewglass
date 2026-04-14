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

    func testQueryByClassNameUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "Label", on: snapshot)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.className.localizedCaseInsensitiveContains("Label") })
    }

    func testQueryByLowercaseBareClassNameUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "label", on: snapshot)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.className.localizedCaseInsensitiveContains("Label") })
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

    func testQueryByControllerClass() throws {
        let results = try engine.execute(expression: "controller:ViewController", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount - 1) // all except UIWindow
        XCTAssertTrue(results.allSatisfy { $0.hostViewControllerClassName == "ViewController" })
    }

    func testQueryByControllerClassUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "controller:View", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount - 1)
    }

    func testPlainControllerClassMatchesHostController() throws {
        let results = try engine.execute(expression: "ViewController", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount - 1)
    }

    func testPlainControllerClassUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "Controller", on: snapshot)
        XCTAssertEqual(results.count, snapshot.totalNodeCount - 1)
    }

    func testUnderscorePrefixedUIKitClassIsRecognized() throws {
        let results = try engine.execute(expression: "_UIAlertControllerPhoneTVMacView", on: snapshot)
        XCTAssertEqual(results.count, 0)
    }

    func testQueryByParent() throws {
        let results = try engine.execute(expression: "parent:UIButton", on: snapshot)
        XCTAssertEqual(results.count, 1) // buttonLabel
        XCTAssertEqual(results[0].className, "UILabel")
    }

    func testQueryByParentUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "parent:Button", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].className, "UILabel")
    }

    func testQueryEmptyExpression() {
        XCTAssertThrowsError(try engine.execute(expression: "", on: snapshot))
    }

    func testQueryUnknownLowercaseBareWordReturnsNoMatches() throws {
        let results = try engine.execute(expression: "invalid_lower", on: snapshot)
        XCTAssertEqual(results.count, 0)
    }

    func testQueryComplexExpression() throws {
        let results = try engine.execute(
            expression: "(UIButton OR UILabel) AND .visible",
            on: snapshot
        )
        // visible UIButton (1) + visible UILabels (2)
        XCTAssertEqual(results.count, 3)
    }

    func testQueryQuotedLabelWithAND() throws {
        // "Terms AND Conditions" should NOT be split on AND
        // This should match accessibility label literally, not split into parts
        let results = try engine.execute(
            expression: "@\"Terms AND Conditions\"",
            on: snapshot
        )
        // No nodes have this label, so 0 results — but it shouldn't crash
        XCTAssertEqual(results.count, 0)
    }

    func testQueryQuotedLabelWithOR() throws {
        // Quoted string with OR inside should not be split
        let results = try engine.execute(
            expression: "@\"Accept OR Decline\"",
            on: snapshot
        )
        XCTAssertEqual(results.count, 0) // No match, but no crash
    }

    // MARK: - contains:

    func testContainsQuotedMatch() throws {
        // "Tap me" label should match partial substring "Tap"
        let results = try engine.execute(expression: "contains:\"Tap\"", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.allSatisfy { $0.accessibilityLabel?.localizedCaseInsensitiveContains("Tap") == true })
    }

    func testContainsCaseInsensitive() throws {
        let results = try engine.execute(expression: "contains:\"tap me\"", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
    }

    func testContainsNoMatch() throws {
        let results = try engine.execute(expression: "contains:\"ZZZnonexistent\"", on: snapshot)
        XCTAssertEqual(results.count, 0)
    }

    func testContainsUnquoted() throws {
        // Unquoted substring also works
        let results = try engine.execute(expression: "contains:Tap", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
    }

    func testContainsCombinedWithAND() throws {
        let results = try engine.execute(expression: "UILabel AND contains:\"Tap\"", on: snapshot)
        XCTAssertTrue(results.allSatisfy { $0.className == "UILabel" })
        XCTAssertTrue(results.allSatisfy { $0.accessibilityLabel?.localizedCaseInsensitiveContains("Tap") == true })
    }

    // MARK: - ancestor:

    func testAncestorMatchesDirectParent() throws {
        // buttonLabel (oid:5) is a direct child of UIButton (oid:4)
        let results = try engine.execute(expression: "ancestor:UIButton", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].oid, 5)
        XCTAssertEqual(results[0].className, "UILabel")
    }

    func testAncestorUsesFuzzyContains() throws {
        let results = try engine.execute(expression: "ancestor:Button", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].oid, 5)
    }

    func testAncestorMatchesTransitiveAncestor() throws {
        // buttonLabel (5) has UIView (3) as grandparent — should match ancestor:UIView
        let results = try engine.execute(expression: "ancestor:UIView", on: snapshot)
        // Nodes with a UIView ancestor: contentView(3), button(4), buttonLabel(5), label(6), overlap(7), hiddenBtn(8)
        XCTAssertEqual(results.count, 6)
    }

    func testAncestorNoMatchOnRoot() throws {
        // UIWindow (1) and viewController UIView (2) have no UIView ancestor
        let results = try engine.execute(expression: "ancestor:UIButton", on: snapshot)
        XCTAssertTrue(results.allSatisfy { $0.oid != 1 && $0.oid != 2 })
    }

    func testAncestorCombinedWithAND() throws {
        // UILabel whose ancestor is UIButton → buttonLabel only
        let results = try engine.execute(expression: "UILabel AND ancestor:UIButton", on: snapshot)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].oid, 5)
    }

    func testAncestorNoMatch() throws {
        let results = try engine.execute(expression: "ancestor:UIScrollView", on: snapshot)
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - text:

    func testTextMatchesCustomDisplayTitle() throws {
        // viewController UIView (2) has customDisplayTitle "ViewController.view"
        let results = try engine.execute(expression: "text:\"ViewController\"", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.contains { $0.oid == 2 })
    }

    func testTextMatchesAccessibilityLabelAsFallback() throws {
        // buttonLabel (5) has accessibilityLabel "Tap me", no customDisplayTitle
        let results = try engine.execute(expression: "text:\"Tap\"", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.contains { $0.oid == 5 })
    }

    func testTextCaseInsensitive() throws {
        let results = try engine.execute(expression: "text:\"welcome\"", on: snapshot)
        XCTAssertGreaterThan(results.count, 0)
    }

    func testTextNoMatch() throws {
        let results = try engine.execute(expression: "text:\"ZZZnonexistent\"", on: snapshot)
        XCTAssertEqual(results.count, 0)
    }

    func testTextCombinedWithAND() throws {
        let results = try engine.execute(expression: "UILabel AND text:\"Tap\"", on: snapshot)
        XCTAssertTrue(results.allSatisfy { $0.className == "UILabel" })
        XCTAssertGreaterThan(results.count, 0)
    }
}
