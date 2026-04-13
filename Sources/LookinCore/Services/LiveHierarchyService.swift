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
        let client = try await sessionService.getClient(for: sessionId)
        let appDescriptor: LKAppDescriptor
        if let session = await sessionService.currentSession(), session.sessionId == sessionId {
            appDescriptor = session.app
        } else if let saved = SessionStore().load(), saved.sessionId == sessionId {
            appDescriptor = saved.app
        } else if let port = Int(sessionId) {
            // Fetch app info directly from the connection
            let appInfo = try await client.fetchAppInfo(needImages: false)
            let deviceType: LKAppDescriptor.DeviceType = LKPortConstants.isSimulatorPort(port) ? .simulator : .device
            appDescriptor = LKBridgeConverter.convertAppInfo(appInfo, host: "127.0.0.1", port: port, deviceType: deviceType)
        } else {
            throw LookinCoreError.sessionNotConnected
        }

        let hierarchyInfo = try await client.fetchHierarchy()
        let snapshot = LKBridgeConverter.convertHierarchy(hierarchyInfo, app: appDescriptor)
        cachedSnapshot = snapshot
        return snapshot
    }

    public func refreshHierarchy(sessionId: String) async throws -> LKHierarchySnapshot {
        cachedSnapshot = nil
        return try await fetchHierarchy(sessionId: sessionId)
    }
}
