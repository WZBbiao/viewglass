import Foundation

public protocol ExportServiceProtocol: Sendable {
    func exportHierarchy(
        snapshot: LKHierarchySnapshot,
        format: ExportFormat,
        outputPath: String
    ) async throws -> String

    func exportReport(
        snapshot: LKHierarchySnapshot,
        outputPath: String
    ) async throws -> String
}

public enum ExportFormat: String, Codable, Sendable {
    case json
    case text
    case html
}
