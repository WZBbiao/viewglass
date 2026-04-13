import Foundation

public struct LKAppDescriptor: Codable, Equatable, Sendable {
    public let appName: String
    public let bundleIdentifier: String
    public let appVersion: String?
    public let deviceName: String?
    public let deviceType: DeviceType
    public let host: String
    public let port: Int
    public let remotePort: Int?
    public let deviceIdentifier: String?
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
        host: String = "127.0.0.1",
        port: Int,
        remotePort: Int? = nil,
        deviceIdentifier: String? = nil,
        serverVersion: String? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.host = host
        self.port = port
        self.remotePort = remotePort
        self.deviceIdentifier = deviceIdentifier
        self.serverVersion = serverVersion
    }

    private enum CodingKeys: String, CodingKey {
        case appName
        case bundleIdentifier
        case appVersion
        case deviceName
        case deviceType
        case host
        case port
        case remotePort
        case deviceIdentifier
        case serverVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.appName = try container.decode(String.self, forKey: .appName)
        self.bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        self.deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        self.deviceType = try container.decodeIfPresent(DeviceType.self, forKey: .deviceType) ?? .simulator
        self.host = try container.decodeIfPresent(String.self, forKey: .host) ?? "127.0.0.1"
        self.port = try container.decode(Int.self, forKey: .port)
        self.remotePort = try container.decodeIfPresent(Int.self, forKey: .remotePort)
        self.deviceIdentifier = try container.decodeIfPresent(String.self, forKey: .deviceIdentifier)
        self.serverVersion = try container.decodeIfPresent(String.self, forKey: .serverVersion)
    }
}
