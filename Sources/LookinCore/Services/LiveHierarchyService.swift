import Foundation
import LookinSharedBridge

/// Live hierarchy service using real TCP connections.
public final class LiveHierarchyService: HierarchyServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private var cachedSnapshot: LKHierarchySnapshot?

    public init(sessionService: LiveSessionService) {
        self.sessionService = sessionService
    }

    public func fetchHierarchy(sessionId: String) async throws -> LKHierarchySnapshot {
        guard let client = sessionService.getClient(for: sessionId) else {
            throw LookinCoreError.sessionNotConnected
        }
        guard let session = await sessionService.currentSession() else {
            throw LookinCoreError.sessionNotConnected
        }

        let hierarchyInfo = try await client.fetchHierarchy()
        let snapshot = LKBridgeConverter.convertHierarchy(hierarchyInfo, app: session.app)
        cachedSnapshot = snapshot
        return snapshot
    }

    public func refreshHierarchy(sessionId: String) async throws -> LKHierarchySnapshot {
        cachedSnapshot = nil
        return try await fetchHierarchy(sessionId: sessionId)
    }
}
