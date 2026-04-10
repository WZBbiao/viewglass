import XCTest
@testable import LookinCore

final class CLICommandTests: XCTestCase {

    // Test the service container mock creation
    func testServiceContainerMock() {
        let container = ServiceContainer.makeMock()
        XCTAssertNotNil(container.session)
        XCTAssertNotNil(container.hierarchy)
        XCTAssertNotNil(container.nodeQuery)
        XCTAssertNotNil(container.screenshot)
        XCTAssertNotNil(container.mutation)
        XCTAssertNotNil(container.export)
        XCTAssertNotNil(container.diagnostics)
    }

    // Test mock session service end-to-end
    func testAppsListFlow() async throws {
        let services = ServiceContainer.makeMock()
        let apps = try await services.session.discoverApps()
        XCTAssertEqual(apps.count, 2)

        // Verify JSON encoding works
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(apps)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("DemoApp"))
        XCTAssertTrue(json.contains("com.example.demo"))
    }

    // Test session connect flow
    func testSessionConnectFlow() async throws {
        let services = ServiceContainer.makeMock()
        let session = try await services.session.connect(appIdentifier: "com.example.demo")
        XCTAssertEqual(session.app.appName, "DemoApp")
        XCTAssertEqual(session.status, .connected)
    }

    // Test hierarchy dump flow
    func testHierarchyDumpFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: "test")
        XCTAssertEqual(snapshot.totalNodeCount, 8)
        XCTAssertEqual(snapshot.appInfo.appName, "DemoApp")

        // JSON encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(snapshot)
        XCTAssertGreaterThan(data.count, 0)
    }

    // Test hierarchy --compact format
    func testHierarchyCompactFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: "test")
        let compact = HierarchyTextFormatter.formatCompact(snapshot: snapshot)

        // Header line
        XCTAssertTrue(compact.contains("DemoApp"), "header should include app name")
        XCTAssertTrue(compact.contains("com.example.demo"), "header should include bundle id")
        XCTAssertTrue(compact.contains("8 nodes"), "header should include node count")

        // Each node should appear with oid and className
        XCTAssertTrue(compact.contains("UIWindow (oid:1)"), "window node")
        XCTAssertTrue(compact.contains("UIButton (oid:4)"), "button node")
        XCTAssertTrue(compact.contains("UILabel (oid:5)"), "label node")

        // Accessibility labels should be shown
        XCTAssertTrue(compact.contains("\"Tap me\""), "button label oid:5 a11y label")
        XCTAssertTrue(compact.contains("\"Welcome\""), "label oid:6 a11y label")

        // Custom display title should be shown
        XCTAssertTrue(compact.contains("\"ViewController.view\""), "VC view custom title")

        // Hidden node should be annotated
        XCTAssertTrue(compact.contains("[hidden]"), "hidden button should be annotated")

        // Compact format should NOT include verbose fields
        XCTAssertFalse(compact.contains("alpha:"), "no alpha in compact output")
        XCTAssertFalse(compact.contains("bounds:"), "no bounds in compact output")

        // Indentation: UIWindow is root (no indent), UIView child has 2-space indent
        let lines = compact.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let windowLine = lines.first(where: { $0.contains("UIWindow") })
        let viewLine = lines.first(where: { $0.contains("UIView (oid:2)") })
        XCTAssertNotNil(windowLine)
        XCTAssertNotNil(viewLine)
        XCTAssertFalse(windowLine!.hasPrefix("  "), "UIWindow should have no indent")
        XCTAssertTrue(viewLine!.hasPrefix("  "), "UIView child should be indented")
    }

    // Test hierarchy --compact --json outputs reduced JSON (not full snapshot)
    func testHierarchyCompactJSONFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: "test")
        let compact = HierarchyTextFormatter.compactSnapshot(from: snapshot)

        // Top-level fields
        XCTAssertTrue(compact.app.contains("DemoApp"))
        XCTAssertTrue(compact.app.contains("com.example.demo"))
        XCTAssertEqual(compact.nodeCount, 8)
        XCTAssertEqual(compact.nodes.count, 1, "one UIWindow root")

        // Flatten all compact nodes for assertions
        func flatten(_ nodes: [LKCompactNode]) -> [LKCompactNode] {
            nodes.flatMap { [$0] + flatten($0.children ?? []) }
        }
        let all = flatten(compact.nodes)
        XCTAssertEqual(all.count, 8)

        let button = all.first(where: { $0.oid == 4 })!
        XCTAssertEqual(button.className, "UIButton")
        XCTAssertEqual(button.frame, [50, 400, 100, 44])

        let labelNode = all.first(where: { $0.oid == 5 })!
        XCTAssertEqual(labelNode.label, "Tap me")

        let vcView = all.first(where: { $0.oid == 2 })!
        XCTAssertEqual(vcView.label, "ViewController.view")

        let hiddenBtn = all.first(where: { $0.oid == 8 })!
        XCTAssertEqual(hiddenBtn.hidden, true)

        // Visible nodes should NOT have `hidden` set (nil = omitted from JSON)
        let visibleBtn = all.first(where: { $0.oid == 4 })!
        XCTAssertNil(visibleBtn.hidden, "visible nodes should have nil hidden")

        // JSON encoding: verify compact keys are used, verbose keys are absent
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(compact)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"class\""), "should use 'class' key")
        XCTAssertFalse(json.contains("\"alpha\""), "should not include alpha")
        XCTAssertFalse(json.contains("\"bounds\""), "should not include bounds")
        XCTAssertFalse(json.contains("\"address\""), "should not include address")
        XCTAssertFalse(json.contains("\"hidden\":false"), "false hidden should be omitted")
    }

    // Test node get flow
    func testNodeGetFlow() async throws {
        let services = ServiceContainer.makeMock()
        let node = try await services.nodeQuery.getNode(oid: 4, sessionId: "test")
        XCTAssertEqual(node.className, "UIButton")
        XCTAssertEqual(node.oid, 4)
    }

    // Test node not found
    func testNodeGetNotFound() async throws {
        let services = ServiceContainer.makeMock()
        do {
            _ = try await services.nodeQuery.getNode(oid: 999, sessionId: "test")
            XCTFail("Expected error")
        } catch let error as LookinCoreError {
            if case .nodeNotFound(let oid) = error {
                XCTAssertEqual(oid, 999)
            } else {
                XCTFail("Wrong error")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // Test query flow
    func testQueryFlow() async throws {
        let services = ServiceContainer.makeMock()
        let nodes = try await services.nodeQuery.queryNodes(expression: "UILabel", sessionId: "test")
        XCTAssertEqual(nodes.count, 2)
    }

    func testLocateFlow() async throws {
        let services = ServiceContainer.makeMock()
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertEqual(resolved.matches.count, 2)
        XCTAssertNil(resolved.selectedTarget)
    }

    // Test select flow
    func testSelectFlow() async throws {
        let services = ServiceContainer.makeMock()
        let node = try await services.nodeQuery.selectNode(oid: 4, sessionId: "test")
        XCTAssertEqual(node.className, "UIButton")
    }

    // Test screenshot flow
    func testScreenshotFlow() async throws {
        let services = ServiceContainer.makeMock()
        let ref = try await services.screenshot.captureScreen(sessionId: "test", outputPath: "/tmp/test.png")
        XCTAssertEqual(ref.screenshotType, .screen)
        XCTAssertEqual(ref.filePath, "/tmp/test.png")
    }

    // Test attr set flow
    func testAttrSetFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.setAttribute(
            nodeOid: 4, key: "alpha", value: "0.5", sessionId: "test"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.nodeOid, 4)
        XCTAssertEqual(result.attributeKey, "alpha")
        XCTAssertEqual(result.newValue, "0.5")
    }

    // Test console eval flow
    func testConsoleEvalFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.invokeMethod(
            nodeOid: 4, selector: "setNeedsLayout", sessionId: "test"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.expression, "setNeedsLayout")
    }

    func testControlTapFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerControlTap(nodeOid: 4, sessionId: "test")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "control-tap")
        XCTAssertEqual(result.mode, .semantic)
    }

    func testTapFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerTap(nodeOid: 4, sessionId: "test")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "tap")
        XCTAssertEqual(result.mode, .semantic)
    }

    func testInputFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.inputText(nodeOid: 4, text: "agent@example.com", sessionId: "test")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "input")
        XCTAssertEqual(result.mode, .semantic)
    }

    func testGestureInspectFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.inspectGestures(nodeOid: 167, sessionId: "test")
        XCTAssertEqual(result.nodeOid, 167)
        XCTAssertEqual(result.gestures.count, 1)
        XCTAssertEqual(result.gestures.first?.actions.first?.selector, "showDetail")
    }

    func testLongPressFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerLongPress(nodeOid: 24, sessionId: "test")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "long-press")
        XCTAssertEqual(result.mode, .semantic)
    }

    func testDismissFlow() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerDismiss(nodeOid: 994, sessionId: "test")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "dismiss")
        XCTAssertEqual(result.mode, .semantic)
    }

    // Test refresh flow
    func testRefreshFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.refreshHierarchy(sessionId: "test")
        XCTAssertEqual(snapshot.totalNodeCount, 8)
    }

    // Test diagnose overlap flow
    func testDiagnoseOverlapFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: "test")
        let result = services.diagnostics.diagnoseOverlap(snapshot: snapshot)
        XCTAssertEqual(result.diagnosticType, .overlap)
        XCTAssertGreaterThan(result.checkedNodeCount, 0)
    }

    // Test diagnose hidden-interactive flow
    func testDiagnoseHiddenInteractiveFlow() async throws {
        let services = ServiceContainer.makeMock()
        let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: "test")
        let result = services.diagnostics.diagnoseHiddenInteractive(snapshot: snapshot)
        XCTAssertEqual(result.diagnosticType, .hiddenInteractive)
        XCTAssertTrue(result.hasIssues) // hiddenButton is hidden + interactive
    }
}
