import XCTest
@testable import LookinCore

final class DiagnosticsServiceTests: XCTestCase {
    let service = DiagnosticsService()
    let snapshot = MockHierarchyService.makeSampleSnapshot()

    func testOverlapDetection() {
        let result = service.diagnoseOverlap(snapshot: snapshot)
        XCTAssertEqual(result.diagnosticType, .overlap)
        // button(4) at (50,400,100,44) and overlappingView(7) at (60,405,80,30) overlap
        XCTAssertTrue(result.hasIssues)
        XCTAssertGreaterThan(result.issues.count, 0)
        let overlapIssue = result.issues.first!
        XCTAssertTrue(overlapIssue.involvedNodes.contains(4) || overlapIssue.involvedNodes.contains(7))
    }

    func testOverlapDetection_noOverlap() {
        let node1 = LKNode(oid: 1, className: "UIView",
                           frame: LKRect(x: 0, y: 0, width: 100, height: 100),
                           bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                           isUserInteractionEnabled: true, depth: 1, parentOid: 0)
        let node2 = LKNode(oid: 2, className: "UIView",
                           frame: LKRect(x: 200, y: 200, width: 100, height: 100),
                           bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                           isUserInteractionEnabled: true, depth: 1, parentOid: 0)
        let root = LKNode(oid: 0, className: "UIWindow",
                          frame: LKRect(x: 0, y: 0, width: 500, height: 500),
                          bounds: LKRect(x: 0, y: 0, width: 500, height: 500),
                          depth: 0)
        let tree = LKNodeTree(node: root, children: [
            LKNodeTree(node: node1),
            LKNodeTree(node: node2),
        ])
        let snap = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(appName: "T", bundleIdentifier: "t", port: 1),
            windows: [tree]
        )
        let result = service.diagnoseOverlap(snapshot: snap)
        XCTAssertFalse(result.hasIssues)
    }

    func testHiddenInteractiveDetection() {
        let result = service.diagnoseHiddenInteractive(snapshot: snapshot)
        XCTAssertEqual(result.diagnosticType, .hiddenInteractive)
        // hiddenButton(8) is hidden + interactive
        XCTAssertTrue(result.hasIssues)
        XCTAssertTrue(result.issues.contains { $0.involvedNodes.contains(8) })
    }

    func testHiddenInteractiveDetection_clean() {
        let node = LKNode(oid: 1, className: "UIButton",
                          bounds: LKRect(x: 0, y: 0, width: 100, height: 44),
                          isHidden: false, alpha: 1.0, isUserInteractionEnabled: true,
                          depth: 0)
        let tree = LKNodeTree(node: node)
        let snap = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(appName: "T", bundleIdentifier: "t", port: 1),
            windows: [tree]
        )
        let result = service.diagnoseHiddenInteractive(snapshot: snap)
        XCTAssertFalse(result.hasIssues)
    }

    func testOffscreenDetection() {
        let result = service.diagnoseOffscreen(snapshot: snapshot)
        XCTAssertEqual(result.diagnosticType, .offscreen)
        // All sample nodes are within screen bounds, so no offscreen issues expected
    }

    func testOffscreenDetection_withOffscreen() {
        let offscreenNode = LKNode(oid: 2, className: "UIView",
                                   frame: LKRect(x: 1000, y: 1000, width: 100, height: 100),
                                   bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
                                   depth: 2, parentOid: 1)
        let root = LKNode(oid: 1, className: "UIWindow",
                          frame: LKRect(x: 0, y: 0, width: 390, height: 844),
                          bounds: LKRect(x: 0, y: 0, width: 390, height: 844),
                          depth: 0)
        let tree = LKNodeTree(node: root, children: [LKNodeTree(node: offscreenNode)])
        let snap = LKHierarchySnapshot(
            appInfo: LKAppDescriptor(appName: "T", bundleIdentifier: "t", port: 1),
            windows: [tree],
            screenSize: LKRect(x: 0, y: 0, width: 390, height: 844)
        )
        let result = service.diagnoseOffscreen(snapshot: snap)
        XCTAssertTrue(result.hasIssues)
        XCTAssertTrue(result.issues.contains { $0.involvedNodes.contains(2) })
    }

    func testDiagnosticResultCodable() throws {
        let result = service.diagnoseOverlap(snapshot: snapshot)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(LKDiagnosticResult.self, from: data)
        XCTAssertEqual(decoded.diagnosticType, result.diagnosticType)
        XCTAssertEqual(decoded.issues.count, result.issues.count)
        XCTAssertEqual(decoded.checkedNodeCount, result.checkedNodeCount)
    }

    func testDiagnosticResultJSONShape() throws {
        let result = service.diagnoseOverlap(snapshot: snapshot)
        let data = try JSONEncoder().encode(result)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["diagnosticType"])
        XCTAssertNotNil(dict["issues"])
        XCTAssertNotNil(dict["summary"])
        XCTAssertNotNil(dict["checkedNodeCount"])
    }
}
