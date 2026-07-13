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
        args: [String],
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

    /// Swipe a target in the given direction.
    /// UIScrollView targets use contentOffset; other UIView targets use coordinate semantic swipe.
    func triggerSwipe(
        nodeOid: UInt,
        direction: LKSwipeDirection,
        distance: CGFloat,
        animated: Bool,
        sessionId: String
    ) async throws -> LKActionResult
}
