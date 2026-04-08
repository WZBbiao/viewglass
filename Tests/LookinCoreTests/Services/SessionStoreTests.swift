import XCTest
@testable import LookinCore

final class SessionStoreTests: XCTestCase {
    private var store: SessionStore!
    private var tempDir: String!

    override func setUp() {
        tempDir = NSTemporaryDirectory() + "lookin-test-\(UUID().uuidString)"
        store = SessionStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testSaveAndLoad() throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "Test", bundleIdentifier: "com.test", port: 47164),
            status: .connected
        )
        try store.save(session)
        XCTAssertTrue(store.exists)

        let loaded = store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.sessionId, "47164")
        XCTAssertEqual(loaded?.app.appName, "Test")
        XCTAssertEqual(loaded?.status, .connected)
    }

    func testClearRemovesFile() throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "Test", bundleIdentifier: "com.test", port: 47164)
        )
        try store.save(session)
        XCTAssertTrue(store.exists)

        try store.clear()
        XCTAssertFalse(store.exists)
        XCTAssertNil(store.load())
    }

    func testClearOnEmptyDoesNotThrow() throws {
        XCTAssertFalse(store.exists)
        XCTAssertNoThrow(try store.clear())
    }

    func testLoadReturnsNilWhenNoFile() {
        XCTAssertNil(store.load())
    }

    func testSaveOverwritesPrevious() throws {
        let s1 = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "App1", bundleIdentifier: "com.app1", port: 47164)
        )
        let s2 = LKSessionDescriptor(
            sessionId: "47165",
            app: LKAppDescriptor(appName: "App2", bundleIdentifier: "com.app2", port: 47165)
        )
        try store.save(s1)
        try store.save(s2)

        let loaded = store.load()
        XCTAssertEqual(loaded?.sessionId, "47165")
        XCTAssertEqual(loaded?.app.appName, "App2")
    }

    func testDisconnectClearsPersistedSession() async throws {
        let session = LKSessionDescriptor(
            sessionId: "47164",
            app: LKAppDescriptor(appName: "Test", bundleIdentifier: "com.test", port: 47164)
        )
        try store.save(session)
        XCTAssertTrue(store.exists)

        // Simulate what LiveSessionService.disconnect does
        try store.clear()
        XCTAssertFalse(store.exists)
        XCTAssertNil(store.load())
    }
}
