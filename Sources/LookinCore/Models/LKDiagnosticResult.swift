import Foundation

public struct LKDiagnosticResult: Codable, Equatable, Sendable {
    public let diagnosticType: DiagnosticType
    public let issues: [LKDiagnosticIssue]
    public let summary: String
    public let checkedNodeCount: Int

    public enum DiagnosticType: String, Codable, Sendable {
        case overlap
        case hiddenInteractive
        case ambiguousLayout
        case offscreen
    }

    public init(
        diagnosticType: DiagnosticType,
        issues: [LKDiagnosticIssue],
        summary: String,
        checkedNodeCount: Int
    ) {
        self.diagnosticType = diagnosticType
        self.issues = issues
        self.summary = summary
        self.checkedNodeCount = checkedNodeCount
    }

    public var hasIssues: Bool { !issues.isEmpty }
}

public struct LKDiagnosticIssue: Codable, Equatable, Sendable {
    public let severity: Severity
    public let message: String
    public let involvedNodes: [UInt]
    public let details: [String: String]?

    public enum Severity: String, Codable, Sendable {
        case warning
        case error
        case info
    }

    public init(
        severity: Severity,
        message: String,
        involvedNodes: [UInt],
        details: [String: String]? = nil
    ) {
        self.severity = severity
        self.message = message
        self.involvedNodes = involvedNodes
        self.details = details
    }
}
