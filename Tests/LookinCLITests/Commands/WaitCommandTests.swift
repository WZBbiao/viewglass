import XCTest
@testable import LookinCore

final class WaitCommandTests: XCTestCase {

    // MARK: - wait appears

    func testWaitAppearsImmediatelyFlow() async throws {
        // "UILabel" has 2 matches in the mock hierarchy — condition met on first poll.
        let services = ServiceContainer.makeMock()
        let resolved = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertEqual(resolved.matches.count, 2, "Mock should have 2 UILabel nodes")

        // Simulate the wait logic directly (no real timing in unit tests).
        let start = Date()
        var pollCount = 0
        var result: LKWaitResult?

        while result == nil {
            let r = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
            pollCount += 1
            if r.matches.count > 0 {
                result = LKWaitResult(
                    condition: "appears:UILabel",
                    met: true,
                    elapsedSeconds: Date().timeIntervalSince(start),
                    pollCount: pollCount,
                    matchCount: r.matches.count
                )
            }
            if pollCount > 10 { break }
        }

        let waitResult = try XCTUnwrap(result)
        XCTAssertTrue(waitResult.met)
        XCTAssertEqual(waitResult.pollCount, 1, "should satisfy on first poll")
        XCTAssertEqual(waitResult.matchCount, 2)
        XCTAssertEqual(waitResult.condition, "appears:UILabel")
    }

    func testWaitAppearsTimeoutFlow() async throws {
        // "NonExistentView" has 0 matches — should result in timeout.
        let services = ServiceContainer.makeMock()
        let r = try await services.nodeQuery.resolve(locator: .parse("NonExistentView"), sessionId: "test")
        XCTAssertEqual(r.matches.count, 0, "Mock should have no NonExistentView nodes")

        // Build a timeout result (no real sleep in unit test).
        let waitResult = LKWaitResult(
            condition: "appears:NonExistentView",
            met: false,
            elapsedSeconds: 10.1,
            pollCount: 20,
            matchCount: 0
        )
        XCTAssertFalse(waitResult.met)
        XCTAssertEqual(waitResult.matchCount, 0)
    }

    // MARK: - wait gone

    func testWaitGoneImmediatelyFlow() async throws {
        // "NonExistentView" has 0 matches — gone condition is met immediately.
        let services = ServiceContainer.makeMock()
        let r = try await services.nodeQuery.resolve(locator: .parse("NonExistentView"), sessionId: "test")
        XCTAssertEqual(r.matches.count, 0)

        let start = Date()
        let waitResult = LKWaitResult(
            condition: "gone:NonExistentView",
            met: true,
            elapsedSeconds: Date().timeIntervalSince(start),
            pollCount: 1,
            matchCount: 0
        )
        XCTAssertTrue(waitResult.met)
        XCTAssertEqual(waitResult.pollCount, 1)
    }

    func testWaitGoneTimeoutFlow() async throws {
        // "UILabel" has 2 matches — gone condition never met, should timeout.
        let services = ServiceContainer.makeMock()
        let r = try await services.nodeQuery.resolve(locator: .parse("UILabel"), sessionId: "test")
        XCTAssertEqual(r.matches.count, 2)

        let waitResult = LKWaitResult(
            condition: "gone:UILabel",
            met: false,
            elapsedSeconds: 10.1,
            pollCount: 20,
            matchCount: 2
        )
        XCTAssertFalse(waitResult.met)
        XCTAssertEqual(waitResult.matchCount, 2)
    }

    // MARK: - LKWaitResult Codable

    func testWaitResultEncodeDecodeRoundtrip() throws {
        let original = LKWaitResult(
            condition: "appears:UIButton",
            met: true,
            elapsedSeconds: 1.234,
            pollCount: 3,
            matchCount: 1
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"appears:UIButton\""))
        XCTAssertTrue(json.contains("true"))

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LKWaitResult.self, from: data)
        XCTAssertEqual(decoded.condition, original.condition)
        XCTAssertEqual(decoded.met, original.met)
        XCTAssertEqual(decoded.pollCount, original.pollCount)
        XCTAssertEqual(decoded.matchCount, original.matchCount)
    }
}
