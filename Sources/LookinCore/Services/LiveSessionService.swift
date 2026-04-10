import Foundation
import LookinSharedBridge

/// Live implementation that connects to real iOS apps via TCP.
/// Persists session state to disk via SessionStore.
public final class LiveSessionService: SessionServiceProtocol, @unchecked Sendable {
    struct DirectConnectionTarget: Equatable {
        let bundleIdentifier: String
        let port: Int
    }

    private var clients: [Int: LKProtocolClient] = [:]
    private var activeSession: LKSessionDescriptor?
    private var activeClient: LKProtocolClient?
    private let store: SessionStore
    private let usbForwardManager: USBForwardManager

    public init(
        store: SessionStore = SessionStore(),
        usbForwardManager: USBForwardManager = USBForwardManager()
    ) {
        self.store = store
        self.usbForwardManager = usbForwardManager
        // Load persisted session info for cross-process reuse.
        if let saved = store.load() {
            activeSession = saved
        }
    }

    public func discoverApps() async throws -> [LKAppDescriptor] {
        let apps = await probeDiscovery().compactMap(\.app)

        if apps.isEmpty {
            throw LookinCoreError.noAppsFound
        }
        return apps
    }

    public func probeDiscovery() async -> [LKDiscoveryProbe] {
        // Use usbmuxd directly to list connected devices (no idevice_id process needed).
        let usbDevices = await usbmuxdDevices()

        return await withTaskGroup(of: (Int, LKDiscoveryProbe).self) { group in
            var index = 0

            for port in LKPortConstants.simulatorPorts {
                let currentIndex = index
                index += 1
                group.addTask {
                    (currentIndex, await self.probeSimulatorApp(host: "127.0.0.1", port: port))
                }
            }

            for device in usbDevices {
                for remotePort in LKPortConstants.devicePorts {
                    let currentIndex = index
                    let udid = device.udid
                    let devID = device.deviceID
                    index += 1
                    group.addTask {
                        (currentIndex, await self.probeUSBApp(
                            udid: udid,
                            usbmuxdDeviceID: devID,
                            remotePort: remotePort
                        ))
                    }
                }
            }

            var ordered: [(Int, LKDiscoveryProbe)] = []
            for await result in group {
                ordered.append(result)
            }
            return ordered.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Query usbmuxd for all currently connected USB devices.
    /// Runs the blocking usbmuxd I/O on a background thread to avoid stalling
    /// Swift's cooperative thread pool.
    private func usbmuxdDevices() async -> [LKUSBMuxdClient.Device] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let mux = LKUSBMuxdClient()
                do {
                    try mux.open()
                    continuation.resume(returning: (try? mux.listDevices()) ?? [])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Resolve a UDID string to the integer deviceID used by usbmuxd.
    private func usbmuxdDeviceID(for udid: String) -> Int? {
        // Synchronous helper used only in non-async contexts (connectClient).
        // Fast path: talk to the local usbmuxd Unix socket.
        let mux = LKUSBMuxdClient()
        guard let _ = try? mux.open() else { return nil }
        return (try? mux.listDevices())?.first { $0.udid == udid }?.deviceID
    }

    private func probeSimulatorApp(host: String, port: Int) async -> LKDiscoveryProbe {
        let client = LKProtocolClient()
        do {
            try await client.connect(host: host, port: port)
            let appInfo = try await client.fetchAppInfo(needImages: false)
            client.disconnect()
            let app = LKBridgeConverter.convertAppInfo(appInfo, host: host, port: port, deviceType: .simulator)
            return LKDiscoveryProbe(host: host, port: port, deviceType: .simulator, status: .discovered, app: app)
        } catch let error as LookinCoreError {
            client.disconnect()
            return LKDiscoveryProbe(
                host: host,
                port: port,
                deviceType: .simulator,
                status: mapProbeStatus(error),
                detail: error.localizedDescription
            )
        } catch {
            client.disconnect()
            return LKDiscoveryProbe(
                host: host,
                port: port,
                deviceType: .simulator,
                status: .protocolError,
                detail: error.localizedDescription
            )
        }
    }

    /// Probe a real device for a LookinServer on `remotePort` using a direct usbmuxd
    /// tunnel – no iproxy process required.  The usbmuxd device whose UDID matches
    /// `udid` is looked up by `deviceID`; after the tunnel is established the
    /// LookinServer port is probed exactly like a simulator port.
    ///
    /// All blocking usbmuxd I/O runs on a background DispatchQueue thread so it never
    /// stalls Swift's cooperative thread pool.
    private func probeUSBApp(udid: String, usbmuxdDeviceID: Int, remotePort: Int) async -> LKDiscoveryProbe {
        // Get the fd on a background thread (blocking usbmuxd I/O).
        let fdResult: Result<Int32, Error> = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let mux = LKUSBMuxdClient()
                do {
                    try mux.open()
                    let fd = try mux.connectToDevice(deviceID: usbmuxdDeviceID, port: UInt16(remotePort))
                    cont.resume(returning: .success(fd))
                } catch {
                    cont.resume(returning: .failure(error))
                }
            }
        }
        let fd: Int32
        switch fdResult {
        case .success(let f): fd = f
        case .failure(let error):
            return LKDiscoveryProbe(
                host: "127.0.0.1", port: remotePort, deviceType: .device,
                deviceIdentifier: udid, remotePort: remotePort,
                status: .connectionFailed, detail: error.localizedDescription
            )
        }
        let client = LKProtocolClient()
        do {
            try await client.connectViaUSB(fd: fd)
            let appInfo = try await client.fetchAppInfo(needImages: false)
            client.disconnect()
            let app = LKBridgeConverter.convertAppInfo(
                appInfo,
                host: "127.0.0.1",
                port: remotePort,
                remotePort: remotePort,
                deviceType: .device,
                deviceIdentifier: udid
            )
            return LKDiscoveryProbe(
                host: "127.0.0.1", port: remotePort, deviceType: .device,
                deviceIdentifier: udid, remotePort: remotePort,
                status: .discovered, app: app
            )
        } catch let error as LookinCoreError {
            client.disconnect()
            return LKDiscoveryProbe(
                host: "127.0.0.1", port: remotePort, deviceType: .device,
                deviceIdentifier: udid, remotePort: remotePort,
                status: mapProbeStatus(error), detail: error.localizedDescription
            )
        } catch {
            client.disconnect()
            return LKDiscoveryProbe(
                host: "127.0.0.1", port: remotePort, deviceType: .device,
                deviceIdentifier: udid, remotePort: remotePort,
                status: .protocolError, detail: error.localizedDescription
            )
        }
    }

    // Keep the old iproxy-based method signature for callers that still provide UDID strings
    // (legacy path used by discoverApp(onPort:)).
    private func probeUSBApp(deviceIdentifier udid: String, remotePort: Int) async -> LKDiscoveryProbe {
        // Resolve UDID → usbmuxd deviceID
        guard let deviceID = usbmuxdDeviceID(for: udid) else {
            return LKDiscoveryProbe(
                host: "127.0.0.1",
                port: remotePort,
                deviceType: .device,
                deviceIdentifier: udid,
                remotePort: remotePort,
                status: .connectionFailed,
                detail: "Device \(udid) not found in usbmuxd device list"
            )
        }
        return await probeUSBApp(udid: udid, usbmuxdDeviceID: deviceID, remotePort: remotePort)
    }

    public func connect(appIdentifier: String) async throws -> LKSessionDescriptor {
        if let target = Self.parseDirectConnectionTarget(appIdentifier) {
            let app = try await connectDirectApp(target: target, originalIdentifier: appIdentifier)
            return try await makeConnectedSession(for: app)
        }

        guard let app = try await discoverApp(matching: appIdentifier) else {
            throw LookinCoreError.appNotFound(identifier: appIdentifier)
        }

        return try await makeConnectedSession(for: app)
    }

    public func disconnect(sessionId: String) async throws {
        let session = try await resolvedSession(sessionId: sessionId)

        if let port = Int(sessionId), let client = clients[port] {
            client.disconnect()
            clients.removeValue(forKey: port)
        }
        // No iproxy process to clean up – usbmuxd tunnels close with the fd.
        // Only clear active session and store if it matches the disconnected one
        if activeSession?.sessionId == sessionId {
            activeClient = nil
            activeSession = nil
            try? store.clear()
        } else if session?.sessionId == sessionId {
            try? store.clear()
        }
    }

    public func currentSession() async -> LKSessionDescriptor? {
        activeSession
    }

    /// Get or create a protocol client for the given session.
    /// If no client exists in memory, reconnects using the persisted session port.
    public func getClient(for sessionId: String) async throws -> LKProtocolClient {
        if let target = Self.parseDirectConnectionTarget(sessionId) {
            let (client, app) = try await connectDirectClient(target: target, originalIdentifier: sessionId)
            let session = LKSessionDescriptor(
                sessionId: sessionId,
                app: app,
                connectedAt: Date(),
                status: .connected
            )
            clients[app.port] = client
            activeClient = client
            activeSession = session
            try? store.save(session)
            return client
        }

        if let port = Int(sessionId), let client = clients[port], client.isConnected {
            do {
                try await verify(client: client, matches: activeSession?.app ?? store.load()?.app)
                return client
            } catch {
                client.disconnect()
                clients.removeValue(forKey: port)
            }
        }

        let resolved = try await resolvedSession(sessionId: sessionId)
        let recovered = resolved == nil ? try await recoverSession(sessionId: sessionId) : nil
        guard var session = resolved ?? recovered else {
            throw LookinCoreError.sessionNotConnected
        }

        var lastError: Error?
        for _ in 0..<3 {
            do {
                return try await connectAndPersist(session: session, app: session.app)
            } catch {
                lastError = error
                guard let rediscovered = try await discoverApp(
                    matching: session.app.bundleIdentifier,
                    attempts: 10,
                    retryDelayNs: 300_000_000
                ) else {
                    break
                }
                session = LKSessionDescriptor(
                    sessionId: "\(rediscovered.port)",
                    app: rediscovered,
                    connectedAt: Date(),
                    status: .connected
                )
            }
        }

        let disconnected = LKSessionDescriptor(
            sessionId: session.sessionId,
            app: session.app,
            connectedAt: session.connectedAt,
            status: .disconnected
        )
        activeSession = disconnected
        try? store.save(disconnected)
        throw lastError ?? LookinCoreError.sessionNotConnected
    }

    /// Disconnect all clients gracefully. Must be called before process exit.
    public func disconnectAll() {
        for (_, client) in clients {
            client.disconnect()
        }
        clients.removeAll()
        activeClient = nil
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

    private func resolvedSession(sessionId: String) async throws -> LKSessionDescriptor? {
        if let activeSession, activeSession.sessionId == sessionId {
            return activeSession
        }
        if let saved = store.load(), saved.sessionId == sessionId {
            return saved
        }
        if let target = Self.parseDirectConnectionTarget(sessionId) {
            let app = try await connectDirectApp(target: target, originalIdentifier: sessionId)
            return LKSessionDescriptor(
                sessionId: sessionId,
                app: app,
                connectedAt: Date(),
                status: .connected
            )
        }
        guard
            let port = Int(sessionId),
            LKPortConstants.simulatorPorts.contains(port) || LKPortConstants.devicePorts.contains(port)
        else {
            return nil
        }
        if let app = try await discoverApp(onPort: port) {
            return try await makeConnectedSession(for: app)
        }
        return nil
    }

    private func recoverSession(sessionId: String) async throws -> LKSessionDescriptor? {
        guard let saved = activeSession ?? store.load() else {
            return nil
        }
        guard saved.status == .connected else {
            return nil
        }

        if let requestedPort = Int(sessionId), let appOnRequestedPort = try await discoverApp(onPort: requestedPort) {
            if appOnRequestedPort.bundleIdentifier == saved.app.bundleIdentifier {
                let recovered = LKSessionDescriptor(
                    sessionId: "\(appOnRequestedPort.port)",
                    app: appOnRequestedPort,
                    connectedAt: Date(),
                    status: .connected
                )
                activeSession = recovered
                try? store.save(recovered)
                return recovered
            }
        }

        guard let rediscovered = try await discoverApp(
            matching: saved.app.bundleIdentifier,
            attempts: 10,
            retryDelayNs: 300_000_000
        ) else {
            return nil
        }

        let recovered = LKSessionDescriptor(
            sessionId: "\(rediscovered.port)",
            app: rediscovered,
            connectedAt: Date(),
            status: .connected
        )
        activeSession = recovered
        try? store.save(recovered)
        return recovered
    }

    private func discoverApp(
        matching appIdentifier: String,
        attempts: Int = 3,
        retryDelayNs: UInt64 = 200_000_000
    ) async throws -> LKAppDescriptor? {
        for _ in 0..<attempts {
            let probes = await probeDiscovery()
            if let app = probes.compactMap(\.app).first(where: { $0.identifier == appIdentifier || $0.bundleIdentifier == appIdentifier }) {
                return app
            }
            try? await Task.sleep(nanoseconds: retryDelayNs)
        }
        return nil
    }

    private func discoverApp(onPort port: Int) async throws -> LKAppDescriptor? {
        if LKPortConstants.simulatorPorts.contains(port) {
            let probe = await probeSimulatorApp(host: "127.0.0.1", port: port)
            return probe.app
        }

        let devices = await usbmuxdDevices()
        for device in devices {
            let probe = await probeUSBApp(udid: device.udid, usbmuxdDeviceID: device.deviceID, remotePort: port)
            if let app = probe.app {
                return app
            }
        }
        return nil
    }

    static func parseDirectConnectionTarget(_ appIdentifier: String) -> DirectConnectionTarget? {
        guard let atIndex = appIdentifier.lastIndex(of: "@") else {
            return nil
        }
        let bundleIdentifier = String(appIdentifier[..<atIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let portString = String(appIdentifier[appIdentifier.index(after: atIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleIdentifier.isEmpty, let port = Int(portString), port > 0 else {
            return nil
        }
        return DirectConnectionTarget(bundleIdentifier: bundleIdentifier, port: port)
    }

    private func connectDirectApp(
        target: DirectConnectionTarget,
        originalIdentifier: String
    ) async throws -> LKAppDescriptor {
        let client = LKProtocolClient()
        do {
            try await client.connect(host: "127.0.0.1", port: target.port)
            let appInfo = try await client.fetchAppInfo(needImages: false)
            guard appInfo.appBundleIdentifier == target.bundleIdentifier else {
                client.disconnect()
                throw LookinCoreError.appNotFound(identifier: originalIdentifier)
            }

            let deviceType: LKAppDescriptor.DeviceType = LKPortConstants.simulatorPorts.contains(target.port) ? .simulator : .device
            let deviceIdentifier: String?
            if deviceType == .device {
                let identifiers = usbForwardManager.connectedDeviceIdentifiers()
                deviceIdentifier = identifiers.count == 1 ? identifiers[0] : nil
            } else {
                deviceIdentifier = nil
            }

            let app = LKBridgeConverter.convertAppInfo(
                appInfo,
                host: "127.0.0.1",
                port: target.port,
                remotePort: LKPortConstants.devicePorts.contains(target.port) ? target.port : nil,
                deviceType: deviceType,
                deviceIdentifier: deviceIdentifier
            )
            client.disconnect()
            return app
        } catch {
            client.disconnect()
            throw error
        }
    }

    private func connectDirectClient(
        target: DirectConnectionTarget,
        originalIdentifier: String
    ) async throws -> (LKProtocolClient, LKAppDescriptor) {
        let client = LKProtocolClient()
        do {
            try await client.connect(host: "127.0.0.1", port: target.port)
            let appInfo = try await client.fetchAppInfo(needImages: false)
            guard appInfo.appBundleIdentifier == target.bundleIdentifier else {
                client.disconnect()
                throw LookinCoreError.appNotFound(identifier: originalIdentifier)
            }

            let deviceType: LKAppDescriptor.DeviceType = LKPortConstants.simulatorPorts.contains(target.port) ? .simulator : .device
            let deviceIdentifier: String?
            if deviceType == .device {
                let identifiers = usbForwardManager.connectedDeviceIdentifiers()
                deviceIdentifier = identifiers.count == 1 ? identifiers[0] : nil
            } else {
                deviceIdentifier = nil
            }

            let app = LKBridgeConverter.convertAppInfo(
                appInfo,
                host: "127.0.0.1",
                port: target.port,
                remotePort: LKPortConstants.devicePorts.contains(target.port) ? target.port : nil,
                deviceType: deviceType,
                deviceIdentifier: deviceIdentifier
            )
            return (client, app)
        } catch {
            client.disconnect()
            throw error
        }
    }

    private func makeConnectedSession(for app: LKAppDescriptor) async throws -> LKSessionDescriptor {
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

    @discardableResult
    private func connectClient(for app: LKAppDescriptor) async throws -> LKProtocolClient {
        if let existing = clients[app.port], existing.isConnected {
            return existing
        }

        let client = LKProtocolClient()

        if app.deviceType == .device {
            // Connect via usbmuxd tunnel – no iproxy process needed.
            // All blocking muxd I/O runs on a background thread.
            guard let udid = app.deviceIdentifier, let remotePort = app.remotePort else {
                throw LookinCoreError.connectionFailed(host: app.host, port: app.port)
            }
            let fd: Int32 = try await withCheckedThrowingContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    let mux = LKUSBMuxdClient()
                    do {
                        try mux.open()
                        guard let deviceID = (try? mux.listDevices())?.first(where: { $0.udid == udid })?.deviceID else {
                            cont.resume(throwing: LookinCoreError.protocolError(
                                reason: "Device \(udid) not found by usbmuxd. Ensure it is connected via USB."
                            ))
                            return
                        }
                        let connFd = try mux.connectToDevice(deviceID: deviceID, port: UInt16(remotePort))
                        cont.resume(returning: connFd)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
            try await client.connectViaUSB(fd: fd)
        } else {
            try await client.connect(host: app.host, port: app.port)
        }

        clients[app.port] = client
        return client
    }

    @discardableResult
    private func connectAndPersist(
        session: LKSessionDescriptor,
        app: LKAppDescriptor,
        persistedSessionId: String? = nil
    ) async throws -> LKProtocolClient {
        let client = try await connectClient(for: app)
        try await verify(client: client, matches: app)
        activeClient = client

        let refreshed = LKSessionDescriptor(
            sessionId: persistedSessionId ?? "\(app.port)",
            app: app,
            connectedAt: Date(),
            status: .connected
        )
        activeSession = refreshed
        try? store.save(refreshed)

        return client
    }

    private func verify(client: LKProtocolClient, matches app: LKAppDescriptor?) async throws {
        guard let app else { return }
        let appInfo = try await client.fetchAppInfo(needImages: false)
        guard appInfo.appBundleIdentifier == app.bundleIdentifier else {
            throw LookinCoreError.appNotFound(identifier: app.bundleIdentifier)
        }
    }

    private func mapProbeStatus(_ error: LookinCoreError) -> LKDiscoveryProbe.Status {
        switch error {
        case .connectionFailed, .connectionTimeout:
            return .connectionFailed
        case .appInBackground:
            return .appInBackground
        case .serverVersionMismatch:
            return .versionMismatch
        default:
            return .protocolError
        }
    }
}
