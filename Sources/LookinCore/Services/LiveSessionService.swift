import Foundation
import LookinSharedBridge

/// Live implementation that connects to real iOS apps via TCP.
/// Persists session state to disk via SessionStore.
public final class LiveSessionService: SessionServiceProtocol, @unchecked Sendable {
    private var clients: [Int: LKProtocolClient] = [:]
    private var activeSession: LKSessionDescriptor?
    private var activeClient: LKProtocolClient?
    private let store: SessionStore

    public init(store: SessionStore = SessionStore()) {
        self.store = store
        // Load persisted session info (but mark as potentially stale — not verified)
        if let saved = store.load() {
            activeSession = LKSessionDescriptor(
                sessionId: saved.sessionId,
                app: saved.app,
                connectedAt: saved.connectedAt,
                status: .disconnected // Mark as disconnected until reconnect verifies
            )
        }
    }

    public func discoverApps() async throws -> [LKAppDescriptor] {
        var apps: [LKAppDescriptor] = []

        for port in LKPortConstants.simulatorPorts {
            if let app = await tryDiscoverApp(host: "127.0.0.1", port: port, deviceType: .simulator) {
                apps.append(app)
            }
        }

        for port in LKPortConstants.devicePorts {
            if let app = await tryDiscoverApp(host: "127.0.0.1", port: port, deviceType: .device) {
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
        let apps = try await discoverApps()
        guard let app = apps.first(where: { $0.identifier == appIdentifier || $0.bundleIdentifier == appIdentifier }) else {
            throw LookinCoreError.appNotFound(identifier: appIdentifier)
        }

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
        try? store.save(session)
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
        store.clear()
    }

    public func currentSession() async -> LKSessionDescriptor? {
        activeSession
    }

    /// Get or create a protocol client for the given session.
    /// If no client exists in memory, reconnects using the persisted session port.
    public func getClient(for sessionId: String) async throws -> LKProtocolClient {
        if let port = Int(sessionId), let client = clients[port], client.isConnected {
            return client
        }

        // Try to reconnect using session port
        guard let port = Int(sessionId) else {
            throw LookinCoreError.sessionNotConnected
        }

        let client = LKProtocolClient()
        try await client.connect(host: "127.0.0.1", port: port)
        clients[port] = client
        activeClient = client

        // Update session status to connected after successful reconnect
        if let current = activeSession, current.sessionId == sessionId {
            activeSession = LKSessionDescriptor(
                sessionId: current.sessionId,
                app: current.app,
                connectedAt: Date(),
                status: .connected
            )
            try? store.save(activeSession!)
        }

        return client
    }

    /// Resolve session ID: use provided value, or fall back to persisted session.
    public func resolveSessionId(_ provided: String?) throws -> String {
        if let provided, !provided.isEmpty {
            return provided
        }
        if let saved = activeSession ?? store.load() {
            return saved.sessionId
        }
        throw LookinCoreError.sessionNotConnected
    }
}
