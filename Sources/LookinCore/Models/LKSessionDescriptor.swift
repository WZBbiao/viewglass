import Foundation

public struct LKSessionDescriptor: Codable, Equatable, Sendable {
    public let sessionId: String
    public let app: LKAppDescriptor
    public let connectedAt: Date
    public let status: SessionStatus

    public enum SessionStatus: String, Codable, Sendable {
        case connected
        case disconnected
        case backgrounded
    }

    public init(
        sessionId: String,
        app: LKAppDescriptor,
        connectedAt: Date = Date(),
        status: SessionStatus = .connected
    ) {
        self.sessionId = sessionId
        self.app = app
        self.connectedAt = connectedAt
        self.status = status
    }
}
