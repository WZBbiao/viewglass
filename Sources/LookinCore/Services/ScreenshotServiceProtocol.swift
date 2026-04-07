import Foundation

public protocol ScreenshotServiceProtocol: Sendable {
    func captureScreen(sessionId: String, outputPath: String) async throws -> LKScreenshotRef
    func captureNode(oid: UInt, sessionId: String, outputPath: String) async throws -> LKScreenshotRef
}
