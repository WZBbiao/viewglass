import Foundation
import CoreGraphics

public protocol MutationServiceProtocol: Sendable {
    func setAttribute(
        nodeOid: UInt,
        key: String,
        value: String,
        sessionId: String
    ) async throws -> LKModificationResult

    func invokeMethod(
        nodeOid: UInt,
        selector: String,
        sessionId: String
    ) async throws -> LKConsoleResult

    func triggerControlTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult

    func triggerTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult

    func triggerLongPress(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult

    func triggerDismiss(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult

    func inputText(
        nodeOid: UInt,
        text: String,
        sessionId: String
    ) async throws -> LKActionResult

    func inspectGestures(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKGestureInspectionResult

    func scrollAnimated(
        nodeOid: UInt,
        targetOffset: CGPoint,
        sessionId: String
    ) async throws -> LKModificationResult

    /// Swipe a UIScrollView by adjusting contentOffset in the given direction.
    /// Fails with actionFailed if the target is not a UIScrollView subclass.
    func triggerSwipe(
        nodeOid: UInt,
        direction: LKSwipeDirection,
        distance: CGFloat,
        animated: Bool,
        sessionId: String
    ) async throws -> LKActionResult
}
