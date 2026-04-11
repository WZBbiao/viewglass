import Foundation

public enum LookinCoreError: Error, LocalizedError, Codable {
    case noAppsFound
    case appNotFound(identifier: String)
    case sessionNotConnected
    case connectionFailed(host: String, port: Int)
    case connectionTimeout
    case nodeNotFound(oid: UInt)
    case querySyntaxError(expression: String, reason: String)
    /// Locator matched more than one node where exactly one is required (mutation commands).
    case locatorNotUnique(locator: String, matchCount: Int, matchOids: [UInt])
    case screenshotFailed(reason: String)
    case attributeModificationFailed(key: String, reason: String)
    case consoleEvalFailed(expression: String, reason: String)
    case actionFailed(action: String, reason: String)
    case exportFailed(reason: String)
    case serverVersionMismatch(server: String, client: String)
    case appInBackground
    case protocolError(reason: String)
    case fileNotFound(path: String)
    case invalidFileFormat(reason: String)

    public var errorDescription: String? {
        switch self {
        case .noAppsFound:
            return "No inspectable apps found"
        case .appNotFound(let id):
            return "App not found: \(id)"
        case .sessionNotConnected:
            return "No active session. Connect to an app first."
        case .connectionFailed(let host, let port):
            return "Connection failed to \(host):\(port)"
        case .connectionTimeout:
            return "Connection timed out"
        case .nodeNotFound(let oid):
            return "Node not found with oid: \(oid)"
        case .querySyntaxError(let expr, let reason):
            return "Query syntax error in '\(expr)': \(reason)"
        case .locatorNotUnique(let locator, let count, let oids):
            let oidList = oids.prefix(5).map { "\($0)" }.joined(separator: ", ")
            let suffix = oids.count > 5 ? " …" : ""
            return "Locator '\(locator)' matched \(count) nodes (oids: \(oidList)\(suffix)). Refine the locator to match exactly one node."
        case .screenshotFailed(let reason):
            return "Screenshot failed: \(reason)"
        case .attributeModificationFailed(let key, let reason):
            return "Failed to modify attribute '\(key)': \(reason)"
        case .consoleEvalFailed(let expr, let reason):
            return "Console eval failed for '\(expr)': \(reason)"
        case .actionFailed(let action, let reason):
            return "Action '\(action)' failed: \(reason)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .serverVersionMismatch(let server, let client):
            return "Server version \(server) incompatible with client \(client)"
        case .appInBackground:
            return "App is in background state"
        case .protocolError(let reason):
            return "Protocol error: \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidFileFormat(let reason):
            return "Invalid file format: \(reason)"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .noAppsFound: return 10
        case .appNotFound: return 11
        case .sessionNotConnected: return 20
        case .connectionFailed: return 21
        case .connectionTimeout: return 22
        case .nodeNotFound: return 30
        case .querySyntaxError: return 31
        case .locatorNotUnique: return 32
        case .screenshotFailed: return 40
        case .attributeModificationFailed: return 50
        case .consoleEvalFailed: return 51
        case .actionFailed: return 52
        case .exportFailed: return 60
        case .serverVersionMismatch: return 70
        case .appInBackground: return 71
        case .protocolError: return 72
        case .fileNotFound: return 80
        case .invalidFileFormat: return 81
        }
    }
}

public struct LKErrorResponse: Codable {
    public let error: Bool
    public let code: Int32
    public let message: String

    public init(from error: LookinCoreError) {
        self.error = true
        self.code = error.exitCode
        self.message = error.errorDescription ?? "Unknown error"
    }

    public init(code: Int32, message: String) {
        self.error = true
        self.code = code
        self.message = message
    }
}
