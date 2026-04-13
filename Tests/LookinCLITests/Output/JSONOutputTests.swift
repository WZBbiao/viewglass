import XCTest
@testable import LookinCore

final class JSONOutputTests: XCTestCase {

    func testAppDescriptorJSONStability() throws {
        let app = LKAppDescriptor(
            appName: "TestApp",
            bundleIdentifier: "com.test.app",
            appVersion: "1.0",
            deviceName: "iPhone 15",
            deviceType: .simulator,
            port: 47164,
            serverVersion: "1.2.8"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(app)
        let json = String(data: data, encoding: .utf8)!

        // Verify stable field names
        XCTAssertTrue(json.contains("\"appName\""))
        XCTAssertTrue(json.contains("\"bundleIdentifier\""))
        XCTAssertTrue(json.contains("\"appVersion\""))
        XCTAssertTrue(json.contains("\"deviceName\""))
        XCTAssertTrue(json.contains("\"deviceType\""))
        XCTAssertTrue(json.contains("\"port\""))
        XCTAssertTrue(json.contains("\"serverVersion\""))
    }

    func testNodeJSONStability() throws {
        let node = LKNode(
            oid: 1,
            className: "UIView",
            address: "0x1",
            frame: LKRect(x: 0, y: 0, width: 100, height: 100),
            bounds: LKRect(x: 0, y: 0, width: 100, height: 100),
            isHidden: false,
            alpha: 1.0,
            isUserInteractionEnabled: true,
            backgroundColor: "#FF0000",
            tag: 0,
            hostViewControllerClassName: "ViewController",
            hostViewControllerOid: 2,
            depth: 0
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(node)
        let json = String(data: data, encoding: .utf8)!

        // Verify stable field names
        XCTAssertTrue(json.contains("\"oid\""))
        XCTAssertTrue(json.contains("\"className\""))
        XCTAssertTrue(json.contains("\"address\""))
        XCTAssertTrue(json.contains("\"frame\""))
        XCTAssertTrue(json.contains("\"bounds\""))
        XCTAssertTrue(json.contains("\"isHidden\""))
        XCTAssertTrue(json.contains("\"alpha\""))
        XCTAssertTrue(json.contains("\"isUserInteractionEnabled\""))
        XCTAssertTrue(json.contains("\"backgroundColor\""))
        XCTAssertTrue(json.contains("\"tag\""))
        XCTAssertTrue(json.contains("\"hostViewControllerClassName\""))
        XCTAssertTrue(json.contains("\"hostViewControllerOid\""))
        XCTAssertTrue(json.contains("\"depth\""))
    }

    func testSessionDescriptorJSONStability() throws {
        let session = LKSessionDescriptor(
            sessionId: "test-123",
            app: LKAppDescriptor(appName: "A", bundleIdentifier: "b", port: 1),
            connectedAt: Date(timeIntervalSince1970: 1000),
            status: .connected
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"sessionId\""))
        XCTAssertTrue(json.contains("\"app\""))
        XCTAssertTrue(json.contains("\"connectedAt\""))
        XCTAssertTrue(json.contains("\"status\""))
        XCTAssertTrue(json.contains("\"connected\""))
    }

    func testDiagnosticResultJSONStability() throws {
        let result = LKDiagnosticResult(
            diagnosticType: .overlap,
            issues: [
                LKDiagnosticIssue(
                    severity: .warning,
                    message: "Overlap detected",
                    involvedNodes: [1, 2],
                    details: ["ratio": "0.5"]
                )
            ],
            summary: "1 issue found",
            checkedNodeCount: 10
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"diagnosticType\""))
        XCTAssertTrue(json.contains("\"issues\""))
        XCTAssertTrue(json.contains("\"summary\""))
        XCTAssertTrue(json.contains("\"checkedNodeCount\""))
        XCTAssertTrue(json.contains("\"severity\""))
        XCTAssertTrue(json.contains("\"message\""))
        XCTAssertTrue(json.contains("\"involvedNodes\""))
    }

    func testErrorResponseJSONStability() throws {
        let response = LKErrorResponse(from: .noAppsFound)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"error\""))
        XCTAssertTrue(json.contains("\"code\""))
        XCTAssertTrue(json.contains("\"message\""))
    }

    func testHierarchySnapshotJSONStability() throws {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"appInfo\""))
        XCTAssertTrue(json.contains("\"windows\""))
        XCTAssertTrue(json.contains("\"fetchedAt\""))
        XCTAssertTrue(json.contains("\"screenScale\""))
        XCTAssertTrue(json.contains("\"screenSize\""))
    }

    func testModificationResultJSONStability() throws {
        let result = LKModificationResult(
            nodeOid: 1,
            attributeKey: "alpha",
            previousValue: "1.0",
            newValue: "0.5"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"nodeOid\""))
        XCTAssertTrue(json.contains("\"attributeKey\""))
        XCTAssertTrue(json.contains("\"previousValue\""))
        XCTAssertTrue(json.contains("\"newValue\""))
        XCTAssertTrue(json.contains("\"success\""))
    }

    func testDiscoveryProbeJSONStability() throws {
        let probe = LKDiscoveryProbe(
            host: "127.0.0.1",
            port: 47164,
            deviceType: .simulator,
            status: .protocolError,
            app: nil,
            detail: "Protocol error: Connection closed"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(probe)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"host\""))
        XCTAssertTrue(json.contains("\"port\""))
        XCTAssertTrue(json.contains("\"deviceType\""))
        XCTAssertTrue(json.contains("\"status\""))
        XCTAssertTrue(json.contains("\"detail\""))
    }
}
