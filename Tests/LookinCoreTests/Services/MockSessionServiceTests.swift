import XCTest
@testable import LookinCore

final class MockSessionServiceTests: XCTestCase {

    func testDiscoverApps() async throws {
        let service = MockSessionService()
        let apps = try await service.discoverApps()
        XCTAssertEqual(apps.count, 2)
        XCTAssertEqual(apps[0].appName, "DemoApp")
        XCTAssertEqual(apps[1].appName, "AnotherApp")
    }

    func testDiscoverApps_failure() async throws {
        let service = MockSessionService()
        service.shouldFail = true
        do {
            _ = try await service.discoverApps()
            XCTFail("Expected error")
        } catch let error as LookinCoreError {
            if case .noAppsFound = error {
                // expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testConnect_byBundleId() async throws {
        let service = MockSessionService()
        let session = try await service.connect(appIdentifier: "com.example.demo")
        XCTAssertEqual(session.app.appName, "DemoApp")
        XCTAssertEqual(session.status, .connected)
        XCTAssertFalse(session.sessionId.isEmpty)
    }

    func testConnect_byIdentifier() async throws {
        let service = MockSessionService()
        let session = try await service.connect(appIdentifier: "com.example.demo@47164")
        XCTAssertEqual(session.app.appName, "DemoApp")
    }

    func testConnect_notFound() async throws {
        let service = MockSessionService()
        do {
            _ = try await service.connect(appIdentifier: "nonexistent")
            XCTFail("Expected error")
        } catch let error as LookinCoreError {
            if case .appNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDisconnect() async throws {
        let service = MockSessionService()
        let session = try await service.connect(appIdentifier: "com.example.demo")
        let beforeDisconnect = await service.currentSession()
        XCTAssertNotNil(beforeDisconnect)
        try await service.disconnect(sessionId: session.sessionId)
        let current = await service.currentSession()
        XCTAssertNil(current)
    }

    func testCurrentSession_none() async {
        let service = MockSessionService()
        let session = await service.currentSession()
        XCTAssertNil(session)
    }
}
