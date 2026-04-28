import XCTest
@testable import LookinCore
import LookinSharedBridge

final class LKBridgeConverterNoiseFilteringTests: XCTestCase {
    func testConvertHierarchyElidesUIKitSystemNoiseWithoutBreakingTreeLinks() {
        let root = makeItem(oid: 1, className: "UIWindow")
        let passthrough = makeItem(oid: 2, className: "_UITouchPassthroughView")
        let scrollEdgeEffect = makeItem(oid: 3, className: "UIKit.ScrollEdgeEffectView")
        let promotedButton = makeItem(oid: 4, className: "UIButton")
        passthrough.subitems = [scrollEdgeEffect, promotedButton]

        let multiLayer = makeItem(oid: 8, className: "_UIMultiLayer")
        multiLayer.subitems = [makeItem(oid: 9, className: "UILabel")]

        let tabBarWrapper = makeItem(oid: 10, className: "UIKit._UITabBarContainerWrapperView")
        let tabBarContainer = makeItem(oid: 11, className: "UIKit._UITabBarContainerView")
        tabBarContainer.subitems = [makeItem(oid: 12, className: "UITabBar")]
        tabBarWrapper.subitems = [tabBarContainer]

        let floatingBar = makeItem(oid: 5, className: "_UIFloatingBarContainerView")
        floatingBar.subitems = [
            makeItem(
                oid: 6,
                className: "_TtGC5UIKitP10$186e04bc422FloatingBarHostingViewVS_20FloatingBarContainer_"
            ),
            makeItem(oid: 7, className: "_UIPointerInteractionAssistantEffectContainerView"),
        ]

        root.subitems = [passthrough, multiLayer, tabBarWrapper, floatingBar]
        let hierarchy = LookinHierarchyInfo()
        hierarchy.displayItems = [root]

        let snapshot = LKBridgeConverter.convertHierarchy(
            hierarchy,
            app: LKAppDescriptor(appName: "Demo", bundleIdentifier: "com.demo", port: 47164)
        )

        XCTAssertEqual(snapshot.flatNodes.map(\.oid), [1, 4, 9, 12])
        XCTAssertEqual(snapshot.windows.first?.node.childrenOids, [4, 9, 12])
        XCTAssertEqual(snapshot.windows.first?.children.first?.node.parentOid, 1)
        XCTAssertEqual(snapshot.windows.first?.children.first?.node.depth, 1)
    }

    private func makeItem(oid: UInt, className: String) -> LookinDisplayItem {
        let object = LookinObject()
        object.oid = oid
        object.classChainList = [className, "UIView", "NSObject"]

        let item = LookinDisplayItem()
        item.viewObject = object
        item.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        item.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
        return item
    }
}
