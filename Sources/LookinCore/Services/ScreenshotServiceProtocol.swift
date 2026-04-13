import Foundation

public protocol ScreenshotServiceProtocol: Sendable {
    func captureScreen(sessionId: String, outputPath: String, preferredDeviceIdentifier: String?) async throws -> LKScreenshotRef
    func captureNode(oid: UInt, sessionId: String, outputPath: String, preferredDeviceIdentifier: String?) async throws -> LKScreenshotRef
}

public extension ScreenshotServiceProtocol {
    func captureScreen(sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        try await captureScreen(sessionId: sessionId, outputPath: outputPath, preferredDeviceIdentifier: nil)
    }

    func captureNode(oid: UInt, sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        try await captureNode(oid: oid, sessionId: sessionId, outputPath: outputPath, preferredDeviceIdentifier: nil)
    }
}
