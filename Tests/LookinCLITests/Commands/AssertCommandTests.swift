import XCTest
@testable import LookinCore

final class AssertCommandTests: XCTestCase {
    let services = ServiceContainer.makeMock()

    // MARK: - assert visible

    func testAssertVisiblePass() async throws {
        // UIButton has 2 nodes: 1 visible (oid:4), 1 hidden (oid:8)
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UIButton"), sessionId: "test")
        let visible = resolved.matches.filter { $0.node.isVisible }
        XCTAssertTrue(!visible.isEmpty, "assert visible should pass — at least one UIButton is visible")
    }

    func testAssertVisibleFailAllHidden() async throws {
        // hidden UIButton (oid:8) matched with .hidden filter → 0 visible
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UIButton AND .hidden"), sessionId: "test")
        let visible = resolved.matches.filter { $0.node.isVisible }
        XCTAssertTrue(visible.isEmpty, "assert visible should fail — all matched nodes are hidden")
    }

    func testAssertVisibleFailNoMatch() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UIScrollView"), sessionId: "test")
        let visible = resolved.matches.filter { $0.node.isVisible }
        XCTAssertEqual(resolved.matches.count, 0)
        XCTAssertTrue(visible.isEmpty, "assert visible should fail — no nodes matched")
    }

    // MARK: - assert count

    func testAssertCountExactMatch() async throws {
        // 2 UILabel nodes in mock snapshot
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        let actual = resolved.matches.count
        XCTAssertEqual(actual, 2, "mock has 2 UILabel nodes")
        XCTAssertTrue(actual == 2, "assert count 2 should pass")
    }

    func testAssertCountExactMismatch() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        let actual = resolved.matches.count
        XCTAssertFalse(actual == 5, "assert count 5 should fail — actual is \(actual)")
    }

    func testAssertCountMinPass() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertTrue(resolved.matches.count >= 1, "min:1 should pass with 2 UILabel nodes")
    }

    func testAssertCountMaxPass() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertTrue(resolved.matches.count <= 3, "max:3 should pass with 2 UILabel nodes")
    }

    func testAssertCountMaxFail() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertFalse(resolved.matches.count <= 1, "max:1 should fail — got 2")
    }

    // MARK: - assert text

    func testAssertTextExactMatch() async throws {
        // buttonLabel (oid:5) has accessibilityLabel "Tap me"
        let resolved = try await services.nodeQuery.resolve(
            locator: .parse("UILabel AND contains:\"Tap me\""), sessionId: "test"
        )
        XCTAssertEqual(resolved.matches.count, 1)
        let node = resolved.matches[0].node
        let text = node.customDisplayTitle ?? node.accessibilityLabel ?? ""
        XCTAssertEqual(text, "Tap me")
    }

    func testAssertTextContainsMatch() async throws {
        let resolved = try await services.nodeQuery.resolve(
            locator: .parse("UILabel AND contains:\"Welcome\""), sessionId: "test"
        )
        XCTAssertEqual(resolved.matches.count, 1)
        let node = resolved.matches[0].node
        let text = node.customDisplayTitle ?? node.accessibilityLabel ?? ""
        XCTAssertTrue(text.localizedCaseInsensitiveContains("welcome"))
    }

    func testAssertTextNoMatch() async throws {
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertGreaterThan(resolved.matches.count, 0)
        // Verify that UILabel nodes don't have the text "ZZZnope"
        let allTexts = resolved.matches.map { $0.node.customDisplayTitle ?? $0.node.accessibilityLabel ?? "" }
        XCTAssertFalse(allTexts.contains("ZZZnope"))
    }
}
