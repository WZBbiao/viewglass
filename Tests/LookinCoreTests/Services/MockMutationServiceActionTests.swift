import XCTest
@testable import LookinCore

final class MockMutationServiceActionTests: XCTestCase {
    func testTriggerControlTapReturnsSemanticActionResult() async throws {
        let service = MockMutationService()
        let result = try await service.triggerControlTap(nodeOid: 42, sessionId: "mock")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "control-tap")
        XCTAssertEqual(result.mode, .semantic)
        XCTAssertEqual(result.nodeOid, 42)
    }

    func testTriggerTapReturnsSemanticActionResult() async throws {
        let service = MockMutationService()
        let result = try await service.triggerTap(nodeOid: 24, sessionId: "mock")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "tap")
        XCTAssertEqual(result.mode, .semantic)
        XCTAssertEqual(result.nodeOid, 24)
    }

    func testInspectGesturesReturnsParsedRecognizerList() async throws {
        let service = MockMutationService()
        let result = try await service.inspectGestures(nodeOid: 167, sessionId: "mock")
        XCTAssertEqual(result.nodeOid, 167)
        XCTAssertEqual(result.targetClass, "UILabel")
        XCTAssertEqual(result.gestures.count, 1)
        XCTAssertEqual(result.gestures.first?.recognizerClass, "UITapGestureRecognizer")
        XCTAssertEqual(result.gestures.first?.actions.first?.selector, "showDetail")
    }

    func testTriggerLongPressReturnsSemanticActionResult() async throws {
        let service = MockMutationService()
        let result = try await service.triggerLongPress(nodeOid: 24, sessionId: "mock")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "long-press")
        XCTAssertEqual(result.mode, .semantic)
        XCTAssertEqual(result.nodeOid, 24)
    }

    // MARK: - invokeMethod (带参调用)

    func testInvokeMethodNoArgsSucceeds() async throws {
        let service = MockMutationService()
        let result = try await service.invokeMethod(nodeOid: 99, selector: "setNeedsLayout", args: [], sessionId: "mock")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.targetOid, 99)
        XCTAssertEqual(result.expression, "setNeedsLayout")
    }

    func testInvokeMethodWithArgsSucceeds() async throws {
        let service = MockMutationService()
        let result = try await service.invokeMethod(nodeOid: 55, selector: "setAlpha:", args: ["0.5"], sessionId: "mock")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.targetOid, 55)
        XCTAssertEqual(result.expression, "setAlpha:")
    }

    func testInvokeMethodFailsWhenShouldFailIsSet() async throws {
        let service = MockMutationService()
        service.shouldFail = true
        do {
            _ = try await service.invokeMethod(nodeOid: 1, selector: "setNeedsLayout", args: [], sessionId: "mock")
            XCTFail("Expected error to be thrown")
        } catch let error as LookinCoreError {
            guard case .consoleEvalFailed(let expr, _) = error else {
                return XCTFail("Unexpected LookinCoreError: \(error)")
            }
            XCTAssertEqual(expr, "setNeedsLayout")
        }
    }
}

