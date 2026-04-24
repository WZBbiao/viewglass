import Foundation

public struct LKCapability: Codable, Equatable, Sendable {
    public let supported: Bool
    public let reason: String?

    public init(supported: Bool, reason: String? = nil) {
        self.supported = supported
        self.reason = reason
    }
}

public struct LKResolvedObjectTargets: Codable, Equatable, Sendable {
    public let inspectOid: UInt
    public let actionOid: UInt
    public let captureOid: UInt
    public let controllerOid: UInt?
    public let scrollOid: UInt?
    public let textInputOid: UInt?

    public init(
        inspectOid: UInt,
        actionOid: UInt,
        captureOid: UInt,
        controllerOid: UInt?,
        scrollOid: UInt? = nil,
        textInputOid: UInt? = nil
    ) {
        self.inspectOid = inspectOid
        self.actionOid = actionOid
        self.captureOid = captureOid
        self.controllerOid = controllerOid
        self.scrollOid = scrollOid
        self.textInputOid = textInputOid
    }
}

public struct LKResolvedMatch: Codable, Equatable, Sendable {
    public let node: LKNode
    public let targets: LKResolvedObjectTargets
    public let capabilities: [String: LKCapability]

    public init(node: LKNode, targets: LKResolvedObjectTargets, capabilities: [String: LKCapability]) {
        self.node = node
        self.targets = targets
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
