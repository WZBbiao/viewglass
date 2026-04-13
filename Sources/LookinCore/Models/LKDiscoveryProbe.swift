import Foundation

public struct LKDiscoveryProbe: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case discovered
        case connectionFailed
        case protocolError
        case appInBackground
        case versionMismatch
    }

    public let host: String
    public let port: Int
    public let deviceType: LKAppDescriptor.DeviceType
    public let deviceIdentifier: String?
    public let remotePort: Int?
    public let status: Status
    public let app: LKAppDescriptor?
    public let detail: String?

    public init(
        host: String,
        port: Int,
        deviceType: LKAppDescriptor.DeviceType,
        deviceIdentifier: String? = nil,
        remotePort: Int? = nil,
        status: Status,
        app: LKAppDescriptor? = nil,
        detail: String? = nil
    ) {
        self.host = host
        self.port = port
        self.deviceType = deviceType
        self.deviceIdentifier = deviceIdentifier
        self.remotePort = remotePort
        self.status = status
        self.app = app
        self.detail = detail
    }
}
