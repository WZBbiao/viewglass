import Foundation

public struct LKScreenshotRef: Codable, Equatable, Sendable {
    public let nodeOid: UInt
    public let screenshotType: ScreenshotType
    public let format: ImageFormat
    public let width: Int
    public let height: Int
    public let dataSize: Int
    public let filePath: String?

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

    public init(
        nodeOid: UInt,
        screenshotType: ScreenshotType,
        format: ImageFormat = .png,
        width: Int = 0,
        height: Int = 0,
        dataSize: Int = 0,
        filePath: String? = nil
    ) {
        self.nodeOid = nodeOid
        self.screenshotType = screenshotType
        self.format = format
        self.width = width
        self.height = height
        self.dataSize = dataSize
        self.filePath = filePath
    }
}
