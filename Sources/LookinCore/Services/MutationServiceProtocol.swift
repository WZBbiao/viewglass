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
}
