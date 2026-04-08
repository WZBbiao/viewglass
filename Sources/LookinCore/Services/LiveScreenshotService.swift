import Foundation

/// Live screenshot service — not yet implemented.
/// Returns explicit errors instead of fake success.
public final class LiveScreenshotService: ScreenshotServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    public func captureScreen(sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        // Screenshot capture requires fetching hierarchy details with image data,
        // which is not yet implemented in the live protocol layer.
        throw LookinCoreError.screenshotFailed(
            reason: "Live screenshot capture is not yet implemented. Use the Lookin GUI app for screenshots."
        )
    }

    public func captureNode(oid: UInt, sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        throw LookinCoreError.screenshotFailed(
            reason: "Live node screenshot capture is not yet implemented. Use the Lookin GUI app for screenshots."
        )
    }
}
