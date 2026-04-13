import Foundation

public final class LiveExportService: ExportServiceProtocol, @unchecked Sendable {
    public init() {}

    public func exportHierarchy(
        snapshot: LKHierarchySnapshot,
        format: ExportFormat,
        outputPath: String
    ) async throws -> String {
        let content: String
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            content = String(data: data, encoding: .utf8) ?? "{}"
        case .text:
            content = HierarchyTextFormatter.format(snapshot: snapshot)
        case .html:
            content = HierarchyTextFormatter.formatHTML(snapshot: snapshot)
        }

        try content.write(toFile: outputPath, atomically: true, encoding: .utf8)
        return outputPath
    }

    public func exportReport(
        snapshot: LKHierarchySnapshot,
        outputPath: String
    ) async throws -> String {
        let report = ReportGenerator.generate(snapshot: snapshot)
        try report.write(toFile: outputPath, atomically: true, encoding: .utf8)
        return outputPath
    }
}
