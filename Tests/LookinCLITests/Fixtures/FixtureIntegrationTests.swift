import XCTest
@testable import LookinCore

final class FixtureIntegrationTests: XCTestCase {

    private func loadFixture() throws -> LKHierarchySnapshot {
        // Find the fixture file relative to the test file
        let testFile = URL(fileURLWithPath: #file)
        let fixtureURL = testFile.deletingLastPathComponent().appendingPathComponent("sample_hierarchy.json")

        guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
            throw XCTSkip("Fixture file not found at \(fixtureURL.path)")
        }

        let data = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LKHierarchySnapshot.self, from: data)
    }

    func testLoadFixture() throws {
        let snapshot = try loadFixture()
        XCTAssertEqual(snapshot.appInfo.appName, "FixtureApp")
        XCTAssertEqual(snapshot.appInfo.bundleIdentifier, "com.fixture.app")
        XCTAssertEqual(snapshot.totalNodeCount, 5)
        XCTAssertEqual(snapshot.windows.count, 1)
    }

    func testFixtureNodeLookup() throws {
        let snapshot = try loadFixture()
        let button = snapshot.findNode(oid: 103)
        XCTAssertNotNil(button)
        XCTAssertEqual(button?.className, "UIButton")
        XCTAssertEqual(button?.tag, 42)
        XCTAssertEqual(button?.accessibilityIdentifier, "submitButton")
    }

    func testFixtureQuery() throws {
        let snapshot = try loadFixture()
        let engine = LKQueryEngine()

        let labels = try engine.execute(expression: "UILabel", on: snapshot)
        XCTAssertEqual(labels.count, 1)
        XCTAssertEqual(labels[0].accessibilityLabel, "Welcome to FixtureApp")

        let visible = try engine.execute(expression: ".visible", on: snapshot)
        XCTAssertEqual(visible.count, 5) // All visible

        let interactive = try engine.execute(expression: ".interactive", on: snapshot)
        XCTAssertEqual(interactive.count, 3) // Window + View + Button

        let byTag = try engine.execute(expression: "tag:42", on: snapshot)
        XCTAssertEqual(byTag.count, 1)
        XCTAssertEqual(byTag[0].className, "UIButton")

        let byId = try engine.execute(expression: "#submitButton", on: snapshot)
        XCTAssertEqual(byId.count, 1)

        let byLabel = try engine.execute(expression: "@\"Welcome to FixtureApp\"", on: snapshot)
        XCTAssertEqual(byLabel.count, 1)
    }

    func testFixtureDiagnostics() throws {
        let snapshot = try loadFixture()
        let service = DiagnosticsService()

        let overlap = service.diagnoseOverlap(snapshot: snapshot)
        XCTAssertFalse(overlap.hasIssues) // No overlapping interactive views

        let hidden = service.diagnoseHiddenInteractive(snapshot: snapshot)
        XCTAssertFalse(hidden.hasIssues) // No hidden interactive views

        let offscreen = service.diagnoseOffscreen(snapshot: snapshot)
        XCTAssertFalse(offscreen.hasIssues) // All views on screen
    }

    func testFixtureExportText() throws {
        let snapshot = try loadFixture()
        let text = HierarchyTextFormatter.format(snapshot: snapshot)
        XCTAssertTrue(text.contains("FixtureApp"))
        XCTAssertTrue(text.contains("com.fixture.app"))
        XCTAssertTrue(text.contains("UIWindow"))
        XCTAssertTrue(text.contains("UIButton"))
        XCTAssertTrue(text.contains("UILabel"))
        XCTAssertTrue(text.contains("UIImageView"))
    }

    func testFixtureExportHTML() throws {
        let snapshot = try loadFixture()
        let html = HierarchyTextFormatter.formatHTML(snapshot: snapshot)
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("FixtureApp"))
        XCTAssertTrue(html.contains("UIButton"))
    }

    func testFixtureReport() throws {
        let snapshot = try loadFixture()
        let report = ReportGenerator.generate(snapshot: snapshot)
        XCTAssertTrue(report.contains("# Lookin Hierarchy Report"))
        XCTAssertTrue(report.contains("Total nodes: 5"))
        XCTAssertTrue(report.contains("UILabel"))
        XCTAssertTrue(report.contains("UIButton"))
        XCTAssertTrue(report.contains("UIImageView"))
    }

    func testFixtureRoundtrip() throws {
        let snapshot = try loadFixture()

        // Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)

        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LKHierarchySnapshot.self, from: encoded)

        XCTAssertEqual(decoded.totalNodeCount, snapshot.totalNodeCount)
        XCTAssertEqual(decoded.appInfo.appName, snapshot.appInfo.appName)
        XCTAssertEqual(decoded.appInfo.bundleIdentifier, snapshot.appInfo.bundleIdentifier)
        XCTAssertEqual(decoded.windows.count, snapshot.windows.count)
    }
}
