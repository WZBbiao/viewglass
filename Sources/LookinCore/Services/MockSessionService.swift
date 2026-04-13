import Foundation

public final class MockSessionService: SessionServiceProtocol, @unchecked Sendable {
    public var mockApps: [LKAppDescriptor] = []
    public var mockSession: LKSessionDescriptor?
    public var shouldFail = false

    public init() {
        mockApps = [
            LKAppDescriptor(
                appName: "DemoApp",
                bundleIdentifier: "com.example.demo",
                appVersion: "1.0.0",
                deviceName: "iPhone 15 Pro",
                deviceType: .simulator,
                port: 47164,
                serverVersion: "1.2.8"
            ),
            LKAppDescriptor(
                appName: "AnotherApp",
                bundleIdentifier: "com.example.another",
                appVersion: "2.1.0",
                deviceName: "iPhone 14",
                deviceType: .device,
                port: 47175,
                serverVersion: "1.2.8"
            ),
        ]
    }

    public func discoverApps() async throws -> [LKAppDescriptor] {
        if shouldFail { throw LookinCoreError.noAppsFound }
        return mockApps
    }

    public func connect(appIdentifier: String) async throws -> LKSessionDescriptor {
        if shouldFail { throw LookinCoreError.connectionFailed(host: "localhost", port: 47164) }
        guard let app = mockApps.first(where: { $0.identifier == appIdentifier || $0.bundleIdentifier == appIdentifier }) else {
            throw LookinCoreError.appNotFound(identifier: appIdentifier)
        }
        let session = LKSessionDescriptor(
            sessionId: UUID().uuidString,
            app: app,
            connectedAt: Date(),
            status: .connected
        )
        mockSession = session
        return session
    }

    public func disconnect(sessionId: String) async throws {
        mockSession = nil
    }

    public func currentSession() async -> LKSessionDescriptor? {
        mockSession
    }
}
