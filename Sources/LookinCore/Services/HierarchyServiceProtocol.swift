import Foundation

public protocol HierarchyServiceProtocol: Sendable {
    func fetchHierarchy(sessionId: String) async throws -> LKHierarchySnapshot
    func refreshHierarchy(sessionId: String) async throws -> LKHierarchySnapshot
}
