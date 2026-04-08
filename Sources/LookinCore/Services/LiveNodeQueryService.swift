import Foundation

/// Live node query service that operates on real hierarchy data.
public final class LiveNodeQueryService: NodeQueryServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService
    private var cachedSnapshot: LKHierarchySnapshot?

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    private func getSnapshot(sessionId: String) async throws -> LKHierarchySnapshot {
        if let cached = cachedSnapshot {
            return cached
        }
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
        cachedSnapshot = snapshot
        return snapshot
    }

    public func getNode(oid: UInt, sessionId: String) async throws -> LKNode {
        let snapshot = try await getSnapshot(sessionId: sessionId)
        guard let node = snapshot.findNode(oid: oid) else {
            throw LookinCoreError.nodeNotFound(oid: oid)
        }
        return node
    }

    public func queryNodes(expression: String, sessionId: String) async throws -> [LKNode] {
        // Validate syntax before network request to give clear error on malformed input
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw LookinCoreError.querySyntaxError(expression: expression, reason: "Empty expression")
        }

        let snapshot = try await getSnapshot(sessionId: sessionId)
        let engine = LKQueryEngine()
        return try engine.execute(expression: expression, on: snapshot)
    }

    public func selectNode(oid: UInt, sessionId: String) async throws -> LKNode {
        return try await getNode(oid: oid, sessionId: sessionId)
    }
}
