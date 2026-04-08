import Foundation

/// Live screenshot service that captures from a running iOS app.
public final class LiveScreenshotService: ScreenshotServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    public func captureScreen(sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)

        // Find the first window's group screenshot from the hierarchy
        // For a proper implementation, we need to fetch hierarchy details with screenshots
        guard let firstWindow = snapshot.windows.first else {
            throw LookinCoreError.screenshotFailed(reason: "No windows in hierarchy")
        }

        // Write placeholder — full screenshot requires fetching hierarchy details
        let data = Data() // TODO: fetch actual screenshot via hierarchy details
        if !data.isEmpty {
            try data.write(to: URL(fileURLWithPath: outputPath))
        }

        return LKScreenshotRef(
            nodeOid: firstWindow.node.oid,
            screenshotType: .screen,
            format: .png,
            width: Int(snapshot.screenSize.width * snapshot.screenScale),
            height: Int(snapshot.screenSize.height * snapshot.screenScale),
            dataSize: data.count,
            filePath: outputPath
        )
    }

    public func captureNode(oid: UInt, sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
        guard let node = snapshot.findNode(oid: oid) else {
            throw LookinCoreError.nodeNotFound(oid: oid)
        }

        return LKScreenshotRef(
            nodeOid: oid,
            screenshotType: .solo,
            format: .png,
            width: Int(node.bounds.width * snapshot.screenScale),
            height: Int(node.bounds.height * snapshot.screenScale),
            dataSize: 0,
            filePath: outputPath
        )
    }
}
