import Foundation

public struct LKAppDescriptor: Codable, Equatable, Sendable {
    public let appName: String
    public let bundleIdentifier: String
    public let appVersion: String?
    public let deviceName: String?
    public let deviceType: DeviceType
    public let port: Int
    public let serverVersion: String?

    public enum DeviceType: String, Codable, Sendable {
        case simulator
        case device
    }

    public var identifier: String {
        "\(bundleIdentifier)@\(port)"
    }

    public init(
        appName: String,
        bundleIdentifier: String,
        appVersion: String? = nil,
        deviceName: String? = nil,
        deviceType: DeviceType = .simulator,
        port: Int,
        serverVersion: String? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.port = port
        self.serverVersion = serverVersion
    }
}
