import XCTest
@testable import LookinCore

/// Tests for LiveSessionService session lifecycle using a real SessionStore
/// backed by a temp directory. No network connections — only state management.
final class LiveSessionServiceTests: XCTestCase {
    private var tempDir: String!
    private var store: SessionStore!

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "lookin-live-test-\(UUID().uuidString)"
        store = SessionStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testInitLoadsPersistedSessionAsDisconnected() throws {
        // Persist a connected session
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164),
            status: .connected
        )
        try store.save(session)

        // New LiveSessionService should load it as disconnected
        let service = LiveSessionService(store: store)
        let loaded = waitForSession(service)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.sessionId, "47164")
        XCTAssertEqual(loaded?.status, .disconnected) // stale = disconnected
    }

    func testDisconnectClearsActiveSessionAndStore() async throws {
        // Persist a session
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164),
            status: .connected
        )
        try store.save(session)

        let service = LiveSessionService(store: store)

        // Disconnect the matching session
        try await service.disconnect(sessionId: "47164")

        // Session should be cleared
        let current = await service.currentSession()
        XCTAssertNil(current)

        // Store file should be deleted
        XCTAssertFalse(store.exists)
        XCTAssertNil(store.load())
    }

    func testDisconnectNonMatchingDoesNotClearActiveSession() async throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164),
            status: .connected
        )
        try store.save(session)

        let service = LiveSessionService(store: store)

        // Disconnect a DIFFERENT session ID
        try await service.disconnect(sessionId: "99999")

        // Active session should still be present
        let current = await service.currentSession()
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.sessionId, "47164")

        // Store should still exist
        XCTAssertTrue(store.exists)
    }

    func testResolveSessionIdFromPersistedSession() throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164)
        )
        try store.save(session)

        let service = LiveSessionService(store: store)
        let resolved = try service.resolveSessionId(nil)
        XCTAssertEqual(resolved, "47164")
    }

    func testResolveSessionIdExplicitOverridesPersisted() throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164)
        )
        try store.save(session)

        let service = LiveSessionService(store: store)
        let resolved = try service.resolveSessionId("47165")
        XCTAssertEqual(resolved, "47165")
    }

    func testResolveSessionIdThrowsWhenNothingSaved() {
        let service = LiveSessionService(store: store)
        XCTAssertThrowsError(try service.resolveSessionId(nil))
    }

    func testResolveSessionIdAfterDisconnect() async throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App", bundleIdentifier: "com.test", port: 47164)
        )
        try store.save(session)

        let service = LiveSessionService(store: store)
        try await service.disconnect(sessionId: "47164")

        // Should throw because session was cleared
        XCTAssertThrowsError(try service.resolveSessionId(nil))
    }

    // Helper to synchronously get currentSession
    private func waitForSession(_ service: LiveSessionService) -> LKSessionDescriptor? {
        let exp = expectation(description: "session")
        var result: LKSessionDescriptor?
        Task {
            result = await service.currentSession()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
        return result
    }
}
