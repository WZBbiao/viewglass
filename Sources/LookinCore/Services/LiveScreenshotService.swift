import AppKit
import Foundation
import LookinSharedBridge

public final class LiveScreenshotService: ScreenshotServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    public func captureScreen(sessionId: String, outputPath: String, preferredDeviceIdentifier: String? = nil) async throws -> LKScreenshotRef {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)
                let data = try await client.fetchHighResolutionScreenScreenshot()
                return try writeScreenshot(
                    data: data,
                    fallbackNodeOid: 0,
                    screenshotType: .screen,
                    outputPath: outputPath
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.screenshotFailed(reason: "Unknown screen capture failure")
    }

    public func captureNode(oid: UInt, sessionId: String, outputPath: String, preferredDeviceIdentifier: String? = nil) async throws -> LKScreenshotRef {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
                guard let node = snapshot.findNode(oid: oid) else {
                    throw LookinCoreError.nodeNotFound(oid: oid)
                }

                guard let layerOid = node.layerOid ?? node.viewOid else {
                    throw LookinCoreError.screenshotFailed(reason: "Node \(oid) does not expose a capturable layer")
                }

                let client = try await sessionService.getClient(for: sessionId)
                let data = try await client.fetchHighResolutionNodeScreenshot(oid: layerOid)
                return try writeScreenshot(
                    data: data,
                    fallbackNodeOid: oid,
                    screenshotType: node.layerOid != nil ? .group : .solo,
                    outputPath: outputPath
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.screenshotFailed(reason: "Unknown node capture failure")
    }

    private func writeScreenshot(
        data: Data,
        fallbackNodeOid: UInt,
        screenshotType: LKScreenshotRef.ScreenshotType,
        outputPath: String
    ) throws -> LKScreenshotRef {
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)

        let format = detectFormat(data)
        let size = try imageSize(for: data)

        return LKScreenshotRef(
            nodeOid: fallbackNodeOid,
            screenshotType: screenshotType,
            format: format,
            width: size.width,
            height: size.height,
            dataSize: data.count,
            filePath: outputURL.path
        )
    }

    private func imageSize(for data: Data) throws -> (width: Int, height: Int) {
        guard let image = NSImage(data: data) else {
            throw LookinCoreError.screenshotFailed(reason: "Captured image data is unreadable")
        }
        let rect = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size), context: nil, hints: nil)?.pixelsWide
        let rep = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size), context: nil, hints: nil)
        return (
            width: rect ?? Int(image.size.width),
            height: rep?.pixelsHigh ?? Int(image.size.height)
        )
    }

    private func detectFormat(_ data: Data) -> LKScreenshotRef.ImageFormat {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return .tiff
        }
        return .png
    }

    private func shouldRetry(after error: Error) -> Bool {
        switch error {
        case let LookinCoreError.protocolError(reason):
            return reason.localizedCaseInsensitiveContains("connection closed")
                || reason.localizedCaseInsensitiveContains("connect failed")
        case let LookinCoreError.appNotFound(identifier):
            return !identifier.isEmpty
        default:
            return false
        }
    }

}
