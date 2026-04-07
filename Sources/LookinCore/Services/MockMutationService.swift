import Foundation

public final class MockMutationService: MutationServiceProtocol, @unchecked Sendable {
    public var shouldFail = false
    public var modifications: [LKModificationResult] = []

    public init() {}

    public func setAttribute(
        nodeOid: UInt,
        key: String,
        value: String,
        sessionId: String
    ) async throws -> LKModificationResult {
        if shouldFail {
            throw LookinCoreError.attributeModificationFailed(key: key, reason: "Mock failure")
        }
        let result = LKModificationResult(
            nodeOid: nodeOid,
            attributeKey: key,
            previousValue: "<previous>",
            newValue: value,
            success: true
        )
        modifications.append(result)
        return result
    }

    public func invokeMethod(
        nodeOid: UInt,
        selector: String,
        sessionId: String
    ) async throws -> LKConsoleResult {
        if shouldFail {
            throw LookinCoreError.consoleEvalFailed(expression: selector, reason: "Mock failure")
        }
        return LKConsoleResult(
            expression: selector,
            targetOid: nodeOid,
            targetClass: "UIView",
            returnValue: "<void>",
            returnType: .void_,
            success: true
        )
    }
}
