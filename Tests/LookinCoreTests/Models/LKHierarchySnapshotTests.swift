import XCTest
@testable import LookinCore

final class LKHierarchySnapshotTests: XCTestCase {

    func testFlatNodes() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let flat = snapshot.flatNodes
        XCTAssertGreaterThan(flat.count, 0)
        // Sample has: window(1), viewController(2), contentView(3), button(4), buttonLabel(5), label(6), overlappingView(7), hiddenButton(8)
        XCTAssertEqual(flat.count, 8)
    }

    func testFindNode() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let button = snapshot.findNode(oid: 4)
        XCTAssertNotNil(button)
        XCTAssertEqual(button?.className, "UIButton")
    }

    func testFindNodeByPrimaryOrRelatedOID() {
        let node = LKNode(
            oid: 11,
            primaryOid: 22,
            oidType: .view,
            viewOid: 22,
            layerOid: 11,
            className: "UILabel",
            hostViewControllerClassName: "HostVC",
            hostViewControllerOid: 33
        )
        let snapshot = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(appName: "A", bundleIdentifier: "b", port: 1),
            windows: [LKNodeTree(node: node)]
        )

        XCTAssertEqual(snapshot.findNode(oid: 11)?.className, "UILabel")
        XCTAssertEqual(snapshot.findNode(oid: 22)?.className, "UILabel")
        XCTAssertEqual(snapshot.findNode(oid: 33)?.className, "UILabel")
    }

    func testFindNode_notFound() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let missing = snapshot.findNode(oid: 999)
        XCTAssertNil(missing)
    }

    func testFindNodesByClass() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let labels = snapshot.findNodes(className: "UILabel")
        XCTAssertEqual(labels.count, 2)
    }

    func testTotalNodeCount() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        XCTAssertEqual(snapshot.totalNodeCount, 8)
    }

    func testNodeTreeFlatten() {
        let child1 = LKNodeTree(node: LKNode(oid: 2, className: "A"))
        let child2 = LKNodeTree(node: LKNode(oid: 3, className: "B"))
        let tree = LKNodeTree(node: LKNode(oid: 1, className: "Root"), children: [child1, child2])
        let flat = tree.flatten()
        XCTAssertEqual(flat.count, 3)
        XCTAssertEqual(flat.map(\.oid), [1, 2, 3])
    }

    func testNodeTreeFind() {
        let child = LKNodeTree(node: LKNode(oid: 2, className: "Child"))
        let tree = LKNodeTree(node: LKNode(oid: 1, className: "Root"), children: [child])
        XCTAssertNotNil(tree.find(oid: 2))
        XCTAssertNil(tree.find(oid: 99))
    }

    func testNodeTreeFilter() {
        let child1 = LKNodeTree(node: LKNode(oid: 2, className: "UILabel"))
        let child2 = LKNodeTree(node: LKNode(oid: 3, className: "UIButton"))
        let tree = LKNodeTree(node: LKNode(oid: 1, className: "UIView"), children: [child1, child2])
        let labels = tree.filter { $0.className == "UILabel" }
        XCTAssertEqual(labels.count, 1)
        XCTAssertEqual(labels[0].oid, 2)
    }

    func testCodable() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        XCTAssertGreaterThan(data.count, 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LKHierarchySnapshot.self, from: data)
        XCTAssertEqual(decoded.totalNodeCount, snapshot.totalNodeCount)
        XCTAssertEqual(decoded.appInfo.appName, snapshot.appInfo.appName)
    }

    func testJSONShape() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["appInfo"])
        XCTAssertNotNil(dict["windows"])
        XCTAssertNotNil(dict["fetchedAt"])
        XCTAssertNotNil(dict["screenScale"])
        XCTAssertNotNil(dict["screenSize"])
    }

    // MARK: - filtered(matching:)
    // Mock hierarchy: UIWindow(1)→UIView(2)→UIView(3)→[UIButton(4)→UILabel(5), UILabel(6), UIView(7), UIButton(8)]

    func testFilteredByClassKeepsAncestorPath() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        // UILabel matches oid:5 and oid:6
        let filtered = try snapshot.filtered(matching: "UILabel")
        let oids = Set(filtered.flatNodes.map { $0.oid })
        // Must include both labels
        XCTAssertTrue(oids.contains(5))
        XCTAssertTrue(oids.contains(6))
        // Must include ancestors (window, vcView, contentView)
        XCTAssertTrue(oids.contains(1))
        XCTAssertTrue(oids.contains(2))
        XCTAssertTrue(oids.contains(3))
        // UIButton(4) is parent of UILabel(5) — must be kept as ancestor
        XCTAssertTrue(oids.contains(4))
        // Sibling branches without matches must be pruned
        XCTAssertFalse(oids.contains(7)) // UIView/overlappingView
        XCTAssertFalse(oids.contains(8)) // UIButton/hiddenButton
        XCTAssertEqual(filtered.totalNodeCount, 6)
    }

    func testFilteredMatchingNodeKeepsFullSubtree() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        // UIButton matches oid:4 (with child 5) and oid:8 — both kept with full subtree
        let filtered = try snapshot.filtered(matching: "UIButton")
        let oids = Set(filtered.flatNodes.map { $0.oid })
        XCTAssertTrue(oids.contains(4))
        XCTAssertTrue(oids.contains(5)) // child of oid:4 — included as part of subtree
        XCTAssertTrue(oids.contains(8))
        // Non-matching siblings without matches pruned
        XCTAssertFalse(oids.contains(6))
        XCTAssertFalse(oids.contains(7))
    }

    func testFilteredWithNoMatchReturnsEmptySnapshot() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let filtered = try snapshot.filtered(matching: "UIScrollView")
        XCTAssertEqual(filtered.totalNodeCount, 0)
        XCTAssertTrue(filtered.windows.isEmpty)
    }

    func testFilteredWithLocatorExpression() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let filtered = try snapshot.filtered(matching: "UIButton AND .visible")
        // Only visible UIButton is oid:4
        let oids = Set(filtered.flatNodes.map { $0.oid })
        XCTAssertTrue(oids.contains(4))
        XCTAssertFalse(oids.contains(8)) // hidden UIButton pruned
    }
}
