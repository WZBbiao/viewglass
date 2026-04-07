import Foundation

public protocol NodeQueryServiceProtocol: Sendable {
    func getNode(oid: UInt, sessionId: String) async throws -> LKNode
    func queryNodes(expression: String, sessionId: String) async throws -> [LKNode]
    func selectNode(oid: UInt, sessionId: String) async throws -> LKNode
}
