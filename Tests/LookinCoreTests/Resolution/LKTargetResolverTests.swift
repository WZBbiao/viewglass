import XCTest
@testable import LookinCore

final class LKTargetResolverTests: XCTestCase {
    private let resolver = LKTargetResolver()

    func testParseLocatorKinds() {
        XCTAssertEqual(LKLocator.parse("oid:24").kind, .oid)
        XCTAssertEqual(LKLocator.parse("primaryOid:25").kind, .primaryOid)
        XCTAssertEqual(LKLocator.parse("#submitButton").kind, .accessibilityIdentifier)
        XCTAssertEqual(LKLocator.parse("@\"Open\"").kind, .accessibilityLabel)
        XCTAssertEqual(LKLocator.parse("controller:UIAlertController").kind, .controller)
        XCTAssertEqual(LKLocator.parse("UILabel").kind, .query)
    }

    func testResolvePrimaryOidSelectsSingleTarget() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let resolved = try resolver.resolve(locator: .parse("primaryOid:4"), in: snapshot)

        XCTAssertEqual(resolved.matches.count, 1)
        XCTAssertEqual(resolved.selectedTarget?.node.className, "UIButton")
        XCTAssertEqual(resolved.selectedTarget?.node.primaryOid, 4)
    }

    func testResolveClassQueryReturnsDiscoveryMatchesWithoutSelection() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let resolved = try resolver.resolve(locator: .parse("UILabel"), in: snapshot)

        XCTAssertEqual(resolved.matches.count, 2)
        XCTAssertNil(resolved.selectedTarget)
    }

    func testCapabilitiesContainReasonsForUnsupportedActions() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let resolved = try resolver.resolve(locator: .parse("@\"Welcome\""), in: snapshot)

        let capabilities = try XCTUnwrap(resolved.selectedTarget?.capabilities)
        XCTAssertEqual(capabilities["scroll"]?.supported, false)
        XCTAssertEqual(capabilities["scroll"]?.reason, "target is not a UIScrollView subclass")
    }
}
