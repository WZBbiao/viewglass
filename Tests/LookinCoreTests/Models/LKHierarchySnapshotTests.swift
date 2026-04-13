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
}
