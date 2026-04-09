import XCTest
@testable import LookinCore

final class LKNodeTests: XCTestCase {

    func testNodeVisibility_visible() {
        let node = LKNode(oid: 1, className: "UIView",
                          bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                          isHidden: false, alpha: 1.0)
        XCTAssertTrue(node.isVisible)
    }

    func testNodeVisibility_hiddenByFlag() {
        let node = LKNode(oid: 1, className: "UIView",
                          bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                          isHidden: true, alpha: 1.0)
        XCTAssertFalse(node.isVisible)
    }

    func testNodeVisibility_hiddenByAlpha() {
        let node = LKNode(oid: 1, className: "UIView",
                          bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                          isHidden: false, alpha: 0.0)
        XCTAssertFalse(node.isVisible)
    }

    func testNodeVisibility_hiddenByZeroBounds() {
        let node = LKNode(oid: 1, className: "UIView",
                          bounds: LKRect(x: 0, y: 0, width: 0, height: 100),
                          isHidden: false, alpha: 1.0)
        XCTAssertFalse(node.isVisible)
    }

    func testNodeDisplayTitle_default() {
        let node = LKNode(oid: 1, className: "UIButton")
        XCTAssertEqual(node.displayTitle, "UIButton")
    }

    func testNodeDisplayTitle_custom() {
        let node = LKNode(oid: 1, className: "UIView", customDisplayTitle: "MyCustomView")
        XCTAssertEqual(node.displayTitle, "MyCustomView")
    }

    func testNodeCodable() throws {
        let node = LKNode(
            oid: 42,
            primaryOid: 24,
            oidType: .view,
            className: "UILabel",
            address: "0x600042",
            frame: LKRect(x: 10, y: 20, width: 200, height: 30),
            bounds: LKRect(x: 0, y: 0, width: 200, height: 30),
            isHidden: false,
            alpha: 0.8,
            isUserInteractionEnabled: false,
            backgroundColor: "#FF0000",
            tag: 7,
            accessibilityLabel: "Hello",
            accessibilityIdentifier: "helloLabel",
            hostViewControllerClassName: "SampleViewController",
            hostViewControllerOid: 99,
            depth: 3,
            parentOid: 10,
            childrenOids: [43, 44]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(node)
        let decoded = try JSONDecoder().decode(LKNode.self, from: data)

        XCTAssertEqual(decoded.oid, 42)
        XCTAssertEqual(decoded.primaryOid, 24)
        XCTAssertEqual(decoded.oidType, .view)
        XCTAssertEqual(decoded.className, "UILabel")
        XCTAssertEqual(decoded.address, "0x600042")
        XCTAssertEqual(decoded.frame.x, 10)
        XCTAssertEqual(decoded.frame.y, 20)
        XCTAssertEqual(decoded.alpha, 0.8)
        XCTAssertEqual(decoded.backgroundColor, "#FF0000")
        XCTAssertEqual(decoded.tag, 7)
        XCTAssertEqual(decoded.accessibilityLabel, "Hello")
        XCTAssertEqual(decoded.accessibilityIdentifier, "helloLabel")
        XCTAssertEqual(decoded.hostViewControllerClassName, "SampleViewController")
        XCTAssertEqual(decoded.hostViewControllerOid, 99)
        XCTAssertEqual(decoded.depth, 3)
        XCTAssertEqual(decoded.parentOid, 10)
        XCTAssertEqual(decoded.childrenOids, [43, 44])
    }

    func testNodeJSONShape() throws {
        let node = LKNode(
            oid: 1,
            primaryOid: 2,
            oidType: .view,
            className: "UIView",
            frame: LKRect(x: 0, y: 0, width: 100, height: 100),
            bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
            hostViewControllerClassName: "RootViewController",
            hostViewControllerOid: 99
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(node)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["oid"])
        XCTAssertNotNil(dict["primaryOid"])
        XCTAssertNotNil(dict["oidType"])
        XCTAssertNotNil(dict["className"])
        XCTAssertNotNil(dict["frame"])
        XCTAssertNotNil(dict["bounds"])
        XCTAssertNotNil(dict["isHidden"])
        XCTAssertNotNil(dict["alpha"])
        XCTAssertNotNil(dict["isUserInteractionEnabled"])
        XCTAssertNotNil(dict["tag"])
        XCTAssertNotNil(dict["hostViewControllerClassName"])
        XCTAssertNotNil(dict["hostViewControllerOid"])
        XCTAssertNotNil(dict["clipsToBounds"])
        XCTAssertNotNil(dict["isOpaque"])
        XCTAssertNotNil(dict["depth"])
        XCTAssertNotNil(dict["childrenOids"])
    }

    func testPrimaryOidDefaultsToViewThenLayerThenOID() {
        let viewNode = LKNode(oid: 10, viewOid: 20, layerOid: 10, className: "UIView")
        XCTAssertEqual(viewNode.primaryOid, 20)

        let layerNode = LKNode(oid: 11, layerOid: 11, className: "CALayer")
        XCTAssertEqual(layerNode.primaryOid, 11)

        let fallbackNode = LKNode(oid: 12, className: "NSObject")
        XCTAssertEqual(fallbackNode.primaryOid, 12)
    }
}
