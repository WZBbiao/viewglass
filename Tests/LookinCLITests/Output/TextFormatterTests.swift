import XCTest
@testable import LookinCore

final class TextFormatterTests: XCTestCase {

    func testHierarchyTextFormat() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let text = HierarchyTextFormatter.format(snapshot: snapshot)

        XCTAssertTrue(text.contains("App: DemoApp"))
        XCTAssertTrue(text.contains("com.example.demo"))
        XCTAssertTrue(text.contains("Nodes: 8"))
        XCTAssertTrue(text.contains("UIWindow"))
        XCTAssertTrue(text.contains("UIButton"))
        XCTAssertTrue(text.contains("UILabel"))
        XCTAssertTrue(text.contains("[hidden]"))
    }

    func testHierarchyHTMLFormat() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let html = HierarchyTextFormatter.formatHTML(snapshot: snapshot)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("DemoApp"))
        XCTAssertTrue(html.contains("UIWindow"))
        XCTAssertTrue(html.contains("class=\"node"))
        XCTAssertTrue(html.contains("class=\"class\""))
    }

    func testReportGeneration() {
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let report = ReportGenerator.generate(snapshot: snapshot)

        XCTAssertTrue(report.contains("# Lookin Hierarchy Report"))
        XCTAssertTrue(report.contains("DemoApp"))
        XCTAssertTrue(report.contains("com.example.demo"))
        XCTAssertTrue(report.contains("Total nodes: 8"))
        XCTAssertTrue(report.contains("## Class Distribution"))
        XCTAssertTrue(report.contains("UILabel"))
        XCTAssertTrue(report.contains("UIButton"))
    }

    func testExportServiceJSON() async throws {
        let service = MockExportService()
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let tmpPath = NSTemporaryDirectory() + "test_export_\(UUID().uuidString).json"

        let path = try await service.exportHierarchy(
            snapshot: snapshot,
            format: .json,
            outputPath: tmpPath
        )

        XCTAssertEqual(path, tmpPath)

        // Verify file was written
        let data = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
        XCTAssertGreaterThan(data.count, 0)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)

        // Cleanup
        try FileManager.default.removeItem(atPath: tmpPath)
    }

    func testExportServiceText() async throws {
        let service = MockExportService()
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let tmpPath = NSTemporaryDirectory() + "test_export_\(UUID().uuidString).txt"

        let path = try await service.exportHierarchy(
            snapshot: snapshot,
            format: .text,
            outputPath: tmpPath
        )

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("UIWindow"))
        XCTAssertTrue(content.contains("DemoApp"))

        try FileManager.default.removeItem(atPath: tmpPath)
    }

    func testExportServiceHTML() async throws {
        let service = MockExportService()
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let tmpPath = NSTemporaryDirectory() + "test_export_\(UUID().uuidString).html"

        let path = try await service.exportHierarchy(
            snapshot: snapshot,
            format: .html,
            outputPath: tmpPath
        )

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("<!DOCTYPE html>"))

        try FileManager.default.removeItem(atPath: tmpPath)
    }

    func testExportReport() async throws {
        let service = MockExportService()
        let snapshot = MockHierarchyService.makeSampleSnapshot()
        let tmpPath = NSTemporaryDirectory() + "test_report_\(UUID().uuidString).md"

        let path = try await service.exportReport(snapshot: snapshot, outputPath: tmpPath)

        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("# Lookin Hierarchy Report"))

        try FileManager.default.removeItem(atPath: tmpPath)
    }
}
