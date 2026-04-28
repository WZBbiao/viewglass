import Foundation

public struct LKScreenshotRef: Codable, Equatable, Sendable {
    public let nodeOid: UInt
    public let screenshotType: ScreenshotType
    public let format: ImageFormat
    public let width: Int
    public let height: Int
    public let dataSize: Int
    public let filePath: String?
    public let captureProvider: CaptureProvider?
    public let fallbackReason: String?
    public let qualityWarnings: [String]
    public let blackPixelRatio: Double?
    public let nonBlackPixelRatio: Double?

    public enum ScreenshotType: String, Codable, Sendable {
        case solo
        case group
        case screen
    }

    public enum ImageFormat: String, Codable, Sendable {
        case png
        case tiff
        case jpeg
    }

    public enum CaptureProvider: String, Codable, Sendable {
        case server
        case simctl
        case pymobiledevice3
        case idevicescreenshot
    }

    public init(
        nodeOid: UInt,
        screenshotType: ScreenshotType,
        format: ImageFormat = .png,
        width: Int = 0,
        height: Int = 0,
        dataSize: Int = 0,
        filePath: String? = nil,
        captureProvider: CaptureProvider? = nil,
        fallbackReason: String? = nil,
        qualityWarnings: [String] = [],
        blackPixelRatio: Double? = nil,
        nonBlackPixelRatio: Double? = nil
    ) {
        self.nodeOid = nodeOid
        self.screenshotType = screenshotType
        self.format = format
        self.width = width
        self.height = height
        self.dataSize = dataSize
        self.filePath = filePath
        self.captureProvider = captureProvider
        self.fallbackReason = fallbackReason
        self.qualityWarnings = qualityWarnings
        self.blackPixelRatio = blackPixelRatio
        self.nonBlackPixelRatio = nonBlackPixelRatio
    }
}
