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

    private func makeHierarchy(
        viewClassChain: [String],
        layerOid: UInt = 42,
        layerClassChain: [String]? = nil
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

        let hierarchy = LookinHierarchyInfo()
        hierarchy.displayItems = [item]
        return hierarchy
    }

    private func tempDir() -> String {
        NSTemporaryDirectory() + "viewglass-mutation-\(UUID().uuidString)"
    }
}
