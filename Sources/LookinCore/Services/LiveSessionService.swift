import Foundation
import LookinSharedBridge

/// Live implementation that connects to real iOS apps via TCP.
public final class LiveSessionService: SessionServiceProtocol, @unchecked Sendable {
    private var clients: [Int: LKProtocolClient] = [:]
    private var activeSession: LKSessionDescriptor?
    private var activeClient: LKProtocolClient?

    public init() {}

    public func discoverApps() async throws -> [LKAppDescriptor] {
        var apps: [LKAppDescriptor] = []

        // Scan simulator ports
        for port in LKPortConstants.simulatorPorts {
            if let app = await tryDiscoverApp(host: "127.0.0.1", port: port, deviceType: .simulator) {
                apps.append(app)
            }
        }

        if apps.isEmpty {
            throw LookinCoreError.noAppsFound
        }
        return apps
    }

    private func tryDiscoverApp(host: String, port: Int, deviceType: LKAppDescriptor.DeviceType) async -> LKAppDescriptor? {
        let client = LKProtocolClient()
        do {
            try await client.connect(host: host, port: port)
            let appInfo = try await client.fetchAppInfo(needImages: false)
            clients[port] = client

            return LKBridgeConverter.convertAppInfo(appInfo, port: port, deviceType: deviceType)
        } catch {
            client.disconnect()
            return nil
        }
    }

    public func connect(appIdentifier: String) async throws -> LKSessionDescriptor {
        // Try to find matching app by port or bundle ID
        let apps = try await discoverApps()
        guard let app = apps.first(where: { $0.identifier == appIdentifier || $0.bundleIdentifier == appIdentifier }) else {
            throw LookinCoreError.appNotFound(identifier: appIdentifier)
        }

        // Use existing client or create new one
        let client: LKProtocolClient
        if let existing = clients[app.port] {
            client = existing
        } else {
            client = LKProtocolClient()
            try await client.connect(host: "127.0.0.1", port: app.port)
            clients[app.port] = client
        }

        activeClient = client
        let session = LKSessionDescriptor(
            sessionId: "\(app.port)",
            app: app,
            connectedAt: Date(),
            status: .connected
        )
        activeSession = session
        return session
    }

    public func disconnect(sessionId: String) async throws {
        if let port = Int(sessionId), let client = clients[port] {
            client.disconnect()
            clients.removeValue(forKey: port)
        }
        if activeSession?.sessionId == sessionId {
            activeClient = nil
            activeSession = nil
        }
    }

    public func currentSession() async -> LKSessionDescriptor? {
        activeSession
    }

    func getClient(for sessionId: String) -> LKProtocolClient? {
        if let port = Int(sessionId) {
            return clients[port]
        }
        return activeClient
    }
}
