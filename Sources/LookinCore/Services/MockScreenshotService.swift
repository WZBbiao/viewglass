import Foundation

public final class MockScreenshotService: ScreenshotServiceProtocol, @unchecked Sendable {
    public var shouldFail = false

    public init() {}

    public func captureScreen(sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        if shouldFail { throw LookinCoreError.screenshotFailed(reason: "Mock failure") }
        return LKScreenshotRef(
            nodeOid: 0,
            screenshotType: .screen,
            format: .png,
            width: 1170,
            height: 2532,
            dataSize: 1024,
            filePath: outputPath
        )
    }

    public func captureNode(oid: UInt, sessionId: String, outputPath: String) async throws -> LKScreenshotRef {
        if shouldFail { throw LookinCoreError.screenshotFailed(reason: "Mock failure") }
        return LKScreenshotRef(
            nodeOid: oid,
            screenshotType: .solo,
            format: .png,
            width: 300,
            height: 200,
            dataSize: 512,
            filePath: outputPath
        )
    }
}
