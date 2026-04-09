import Foundation

public struct LKCapability: Codable, Equatable, Sendable {
    public let supported: Bool
    public let reason: String?

    public init(supported: Bool, reason: String? = nil) {
        self.supported = supported
        self.reason = reason
    }
}

public struct LKResolvedMatch: Codable, Equatable, Sendable {
    public let node: LKNode
    public let capabilities: [String: LKCapability]

    public init(node: LKNode, capabilities: [String: LKCapability]) {
        self.node = node
        self.capabilities = capabilities
    }
}

public struct LKResolvedTarget: Codable, Equatable, Sendable {
    public let locator: LKLocator
    public let snapshotId: String
    public let fetchedAt: Date
    public let matches: [LKResolvedMatch]
    public let selectedTarget: LKResolvedMatch?

    public init(
        locator: LKLocator,
        snapshotId: String,
        fetchedAt: Date,
        matches: [LKResolvedMatch],
        selectedTarget: LKResolvedMatch?
    ) {
        self.locator = locator
        self.snapshotId = snapshotId
        self.fetchedAt = fetchedAt
        self.matches = matches
        self.selectedTarget = selectedTarget
    }
}
