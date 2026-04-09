import Foundation

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

    func inspectGestures(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKGestureInspectionResult
}
