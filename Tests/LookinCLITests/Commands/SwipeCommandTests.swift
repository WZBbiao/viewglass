import XCTest
@testable import LookinCore

final class SwipeCommandTests: XCTestCase {

    // MARK: - LKSwipeDirection

    func testSwipeDirectionRawValues() {
        XCTAssertEqual(LKSwipeDirection.up.rawValue, "up")
        XCTAssertEqual(LKSwipeDirection.down.rawValue, "down")
        XCTAssertEqual(LKSwipeDirection.left.rawValue, "left")
        XCTAssertEqual(LKSwipeDirection.right.rawValue, "right")
    }

    func testSwipeDirectionParsing() {
        XCTAssertEqual(LKSwipeDirection(rawValue: "up"), .up)
        XCTAssertEqual(LKSwipeDirection(rawValue: "left"), .left)
        XCTAssertNil(LKSwipeDirection(rawValue: "diagonal"), "unknown direction should be nil")
    }

    func testSwipeDirectionScrollAxisDescription() {
        // Swipe up = content scrolls up = contentOffset.y increases
        XCTAssertTrue(LKSwipeDirection.up.scrollAxisDescription.contains("contentOffset.y +"))
        XCTAssertTrue(LKSwipeDirection.down.scrollAxisDescription.contains("contentOffset.y -"))
        XCTAssertTrue(LKSwipeDirection.left.scrollAxisDescription.contains("contentOffset.x +"))
        XCTAssertTrue(LKSwipeDirection.right.scrollAxisDescription.contains("contentOffset.x -"))
    }

    func testSwipeDirectionCodable() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(LKSwipeDirection.up)
        let decoded = try JSONDecoder().decode(LKSwipeDirection.self, from: data)
        XCTAssertEqual(decoded, .up)
    }

    // MARK: - Mock service flow

    func testSwipeFlowMockSuccess() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerSwipe(
            nodeOid: 4,
            direction: .up,
            distance: 200,
            animated: false,
            sessionId: "test"
        )
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.action, "swipe")
        XCTAssertEqual(result.mode, .semantic)
        XCTAssertTrue(result.detail?.contains("up") == true, "detail should mention direction")
        XCTAssertTrue(result.detail?.contains("200") == true, "detail should mention distance")
    }

    func testSwipeAnimatedFlowMockSuccess() async throws {
        let services = ServiceContainer.makeMock()
        let result = try await services.mutation.triggerSwipe(
            nodeOid: 4,
            direction: .down,
            distance: 150,
            animated: true,
            sessionId: "test"
        )
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.detail?.contains("animated") == true, "animated swipe should say (animated)")
    }

    func testSwipeFlowMockFailure() async throws {
        let mock = MockMutationService()
        mock.shouldFail = true
        do {
            _ = try await mock.triggerSwipe(nodeOid: 4, direction: .left, distance: 100, animated: false, sessionId: "test")
            XCTFail("Expected error")
        } catch let error as LookinCoreError {
            if case .actionFailed(let action, _) = error {
                XCTAssertEqual(action, "swipe")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - All CaseIterable cases

    func testAllSwipeDirectionsCoveredByMock() async throws {
        let services = ServiceContainer.makeMock()
        for direction in LKSwipeDirection.allCases {
            let result = try await services.mutation.triggerSwipe(
                nodeOid: 4,
                direction: direction,
                distance: 100,
                animated: false,
                sessionId: "test"
            )
            XCTAssertTrue(result.success, "swipe \(direction.rawValue) should succeed in mock")
        }
    }
}
