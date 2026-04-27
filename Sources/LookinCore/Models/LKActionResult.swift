import Foundation

public enum LKActionMode: String, Codable, Equatable, Sendable {
    case semantic
    case physical
}

public struct LKActionResult: Codable, Equatable, Sendable {
    public let action: String
    public let nodeOid: UInt
    public let targetClass: String
    public let mode: LKActionMode
    public let success: Bool
    public let detail: String?
    public let strategyUsed: String?
    public let fallbackReason: String?
    public let pointX: Double?
    public let pointY: Double?
    public let hitOid: UInt?
    public let hitClass: String?

    public init(
        action: String,
        nodeOid: UInt,
        targetClass: String,
        mode: LKActionMode,
        success: Bool,
        detail: String? = nil,
        strategyUsed: String? = nil,
        fallbackReason: String? = nil,
        pointX: Double? = nil,
        pointY: Double? = nil,
        hitOid: UInt? = nil,
        hitClass: String? = nil
    ) {
        self.action = action
        self.nodeOid = nodeOid
        self.targetClass = targetClass
        self.mode = mode
        self.success = success
        self.detail = detail
        self.strategyUsed = strategyUsed
        self.fallbackReason = fallbackReason
        self.pointX = pointX
        self.pointY = pointY
        self.hitOid = hitOid
        self.hitClass = hitClass
    }
}
