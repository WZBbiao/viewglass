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
        XCTAssertEqual(resolved.selectedTarget?.targets.inspectOid, 4)
        XCTAssertEqual(resolved.selectedTarget?.targets.actionOid, 4)
        XCTAssertEqual(resolved.selectedTarget?.targets.captureOid, 4)
        XCTAssertNil(resolved.selectedTarget?.targets.controllerOid)
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
        XCTAssertEqual(capabilities["dismiss"]?.supported, false)
    }

    func testResolvePrimaryOidMatchesHostViewControllerOid() throws {
        let node = LKNode(
            oid: 10,
            primaryOid: 11,
            oidType: .layer,
            viewOid: 11,
            layerOid: 10,
            className: "_UIAlertControllerPhoneTVMacView",
            hostViewControllerClassName: "UIAlertController",
            hostViewControllerOid: 99
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("primaryOid:99"), in: snapshot)

        XCTAssertEqual(resolved.matches.count, 1)
        XCTAssertEqual(resolved.selectedTarget?.node.hostViewControllerOid, 99)
        XCTAssertEqual(resolved.selectedTarget?.targets.inspectOid, 10)
        XCTAssertEqual(resolved.selectedTarget?.targets.actionOid, 11)
        XCTAssertEqual(resolved.selectedTarget?.targets.captureOid, 10)
        XCTAssertEqual(resolved.selectedTarget?.targets.controllerOid, 99)
        XCTAssertEqual(resolved.selectedTarget?.capabilities["dismiss"]?.supported, true)
    }

    func testCustomCollectionViewExposesDedicatedScrollTarget() throws {
        let node = LKNode(
            oid: 100,
            primaryOid: 101,
            oidType: .layer,
            viewOid: 101,
            layerOid: 100,
            className: "TapBaseCollectionView",
            hostViewControllerClassName: "FeedViewController"
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("oid:101"), in: snapshot)

        XCTAssertEqual(resolved.selectedTarget?.targets.inspectOid, 100)
        XCTAssertEqual(resolved.selectedTarget?.targets.actionOid, 101)
        XCTAssertEqual(resolved.selectedTarget?.targets.scrollOid, 101)
        XCTAssertEqual(resolved.selectedTarget?.capabilities["scroll"]?.supported, true)
    }

    func testPrivateTextFieldExposesDedicatedInputTarget() throws {
        let node = LKNode(
            oid: 200,
            primaryOid: 201,
            oidType: .layer,
            viewOid: 201,
            layerOid: 200,
            className: "_UIAlertControllerTextField",
            hostViewControllerClassName: "UIAlertController",
            hostViewControllerOid: 299
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("oid:201"), in: snapshot)

        XCTAssertEqual(resolved.selectedTarget?.targets.textInputOid, 201)
        XCTAssertEqual(resolved.selectedTarget?.capabilities["input"]?.supported, true)
    }

    func testWKContentViewExposesDedicatedInputTarget() throws {
        let node = LKNode(
            oid: 250,
            primaryOid: 251,
            oidType: .view,
            viewOid: 251,
            className: "WKContentView"
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("oid:251"), in: snapshot)

        XCTAssertEqual(resolved.selectedTarget?.targets.textInputOid, 251)
        XCTAssertEqual(resolved.selectedTarget?.capabilities["input"]?.supported, true)
    }

    func testAlertActionViewIsNotReportedAsDismissableController() throws {
        let node = LKNode(
            oid: 300,
            primaryOid: 300,
            oidType: .view,
            viewOid: 300,
            className: "_UIAlertControllerActionView",
            accessibilityLabel: "Ship"
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("@\"Ship\""), in: snapshot)

        XCTAssertEqual(resolved.selectedTarget?.capabilities["tap"]?.supported, true)
        XCTAssertEqual(resolved.selectedTarget?.capabilities["dismiss"]?.supported, false)
    }

    func testResolveControllerLocatorUsesFuzzyContains() throws {
        let node = LKNode(
            oid: 10,
            primaryOid: 11,
            oidType: .layer,
            viewOid: 11,
            layerOid: 10,
            className: "_UIAlertControllerPhoneTVMacView",
            hostViewControllerClassName: "UIAlertController",
            hostViewControllerOid: 99
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(
                appName: "Demo",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0",
                deviceName: "iPhone",
                deviceType: .simulator,
                port: 47164
            ),
            windows: [LKNodeTree(node: node)]
        )

        let resolved = try resolver.resolve(locator: .parse("controller:Alert"), in: snapshot)

        XCTAssertEqual(resolved.matches.count, 1)
        XCTAssertEqual(resolved.selectedTarget?.node.hostViewControllerClassName, "UIAlertController")
    }
}
