import XCTest
@testable import LookinCore
import LookinSharedBridge

final class LiveMutationServicePreflightTests: XCTestCase {
    func testResolveTargetMetadataUsesViewObjectByDefault() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))
        let hierarchy = makeHierarchy(viewClassChain: ["UIButton", "UIControl", "UIView", "NSObject"])

        let target = try service.resolveTargetMetadata(nodeOid: 42, isLayerProperty: false, hierarchy: hierarchy)

        XCTAssertEqual(target.objectOid, 42)
        XCTAssertEqual(target.className, "UIButton")
        XCTAssertEqual(target.classChain, ["UIButton", "UIControl", "UIView", "NSObject"])
    }

    func testResolveTargetMetadataUsesLayerObjectForLayerProperties() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))
        let hierarchy = makeHierarchy(
            viewClassChain: ["UIButton", "UIControl", "UIView", "NSObject"],
            layerOid: 77,
            layerClassChain: ["CALayer", "NSObject"]
        )

        let target = try service.resolveTargetMetadata(nodeOid: 77, isLayerProperty: true, hierarchy: hierarchy)

        XCTAssertEqual(target.objectOid, 77)
        XCTAssertEqual(target.className, "CALayer")
        XCTAssertEqual(target.classChain, ["CALayer", "NSObject"])
    }

    func testResolveTargetMetadataUsesViewObjectWhenInteractionTargetsLayerOID() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))
        let hierarchy = makeHierarchy(
            viewClassChain: ["UILabel", "UIView", "NSObject"],
            layerOid: 77,
            layerClassChain: ["_UILabelLayer", "CALayer", "NSObject"]
        )

        let target = try service.resolveTargetMetadata(nodeOid: 77, isLayerProperty: false, hierarchy: hierarchy)

        XCTAssertEqual(target.objectOid, 42)
        XCTAssertEqual(target.className, "UILabel")
        XCTAssertEqual(target.classChain, ["UILabel", "UIView", "NSObject"])
    }

    func testResolveTargetMetadataUsesHostViewControllerObjectWhenOIDMatchesController() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))
        let hierarchy = makeHierarchy(
            viewClassChain: ["_UIAlertControllerPhoneTVMacView", "UIView", "NSObject"],
            hostControllerOid: 994,
            hostControllerClassChain: ["UIAlertController", "UIViewController", "UIResponder", "NSObject"]
        )

        let target = try service.resolveTargetMetadata(nodeOid: 994, isLayerProperty: false, hierarchy: hierarchy)

        XCTAssertEqual(target.objectOid, 994)
        XCTAssertEqual(target.className, "UIAlertController")
        XCTAssertEqual(target.classChain, ["UIAlertController", "UIViewController", "UIResponder", "NSObject"])
    }

    func testResolveCoordinateTapTargetCalculatesScreenPointFromAncestorFrames() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))
        let rootObject = LookinObject()
        rootObject.oid = 1
        rootObject.classChainList = ["UIWindow", "UIView", "NSObject"]
        let root = LookinDisplayItem()
        root.viewObject = rootObject
        root.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        root.bounds = CGRect(x: 0, y: 20, width: 390, height: 844)

        let childObject = LookinObject()
        childObject.oid = 42
        childObject.classChainList = ["UIView", "UIResponder", "NSObject"]
        let child = LookinDisplayItem()
        child.viewObject = childObject
        child.frame = CGRect(x: 30, y: 80, width: 120, height: 40)
        child.bounds = CGRect(x: 0, y: 0, width: 120, height: 40)
        root.subitems = [child]

        let appInfo = LookinAppInfo()
        appInfo.screenWidth = 390
        appInfo.screenHeight = 844
        let hierarchy = LookinHierarchyInfo()
        hierarchy.appInfo = appInfo
        hierarchy.displayItems = [root]

        let target = try service.resolveCoordinateTapTarget(nodeOid: 42, isLayerProperty: false, hierarchy: hierarchy)

        XCTAssertEqual(target.metadata.objectOid, 42)
        XCTAssertEqual(target.frameToRoot.origin.x, 30)
        XCTAssertEqual(target.frameToRoot.origin.y, 60)
        XCTAssertEqual(target.point.x, 90)
        XCTAssertEqual(target.point.y, 80)
    }

    func testEnsureClassChainAcceptsSubclassMatch() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))

        XCTAssertNoThrow(
            try service.ensureClassChain(
                ["UIButton", "UIControl", "UIView", "NSObject"],
                contains: "UIControl",
                action: "control-tap",
                targetClass: "UIButton"
            )
        )
    }

    func testEnsureClassChainAcceptsPrivateTextInputClassName() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))

        XCTAssertNoThrow(
            try service.ensureClassChain(
                ["_UIAlertControllerTextField", "UIView", "NSObject"],
                contains: "UITextField",
                action: "input",
                targetClass: "_UIAlertControllerTextField"
            )
        )
    }

    func testEnsureClassChainAcceptsWKContentViewInputTarget() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))

        XCTAssertNoThrow(
            try service.ensureClassChain(
                ["WKContentView", "WKApplicationStateTrackingView", "UIView"],
                containsAny: ["UITextField", "UITextView", "WKWebView", "WKContentView"],
                action: "input",
                targetClass: "WKContentView"
            )
        )
    }

    func testEnsureClassChainRejectsUnexpectedTargetClass() throws {
        let service = LiveMutationService(sessionService: LiveSessionService(store: SessionStore(directory: tempDir())))

        XCTAssertThrowsError(
            try service.ensureClassChain(
                ["UILabel", "UIView", "NSObject"],
                contains: "UIControl",
                action: "control-tap",
                targetClass: "UILabel"
            )
        ) { error in
            guard case let LookinCoreError.actionFailed(action, reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(action, "control-tap")
            XCTAssertTrue(reason.contains("UILabel is not a UIControl subclass"))
        }
    }

    func testAttributeRegistryRequiresScrollViewForContentOffset() {
        let mapping = LKAttributeRegistry.mapping(for: "contentOffset")
        XCTAssertEqual(mapping?.requiredClass, "UIScrollView")
    }

    func testAttributeRegistryAllowsTextOnTextInputs() {
        let mapping = LKAttributeRegistry.mapping(for: "text")
        XCTAssertEqual(mapping?.requiredClasses, ["UILabel", "UITextField", "UITextView"])
    }

    private func makeHierarchy(
        viewClassChain: [String],
        layerOid: UInt = 42,
        layerClassChain: [String]? = nil,
        hostControllerOid: UInt? = nil,
        hostControllerClassChain: [String]? = nil
    ) -> LookinHierarchyInfo {
        let viewObject = LookinObject()
        viewObject.oid = 42
        viewObject.classChainList = viewClassChain

        let item = LookinDisplayItem()
        item.viewObject = viewObject
        item.layerObject = {
            let layerObject = LookinObject()
            layerObject.oid = UInt(layerOid)
            layerObject.classChainList = layerClassChain
            return layerObject
        }()
        if let hostControllerOid {
            let controllerObject = LookinObject()
            controllerObject.oid = hostControllerOid
            controllerObject.classChainList = hostControllerClassChain
            item.hostViewControllerObject = controllerObject
        }

        let hierarchy = LookinHierarchyInfo()
        hierarchy.displayItems = [item]
        return hierarchy
    }

    private func tempDir() -> String {
        NSTemporaryDirectory() + "viewglass-mutation-\(UUID().uuidString)"
    }
}
