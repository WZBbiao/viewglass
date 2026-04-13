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
}
