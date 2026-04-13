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

    public init(
        action: String,
        nodeOid: UInt,
        targetClass: String,
        mode: LKActionMode,
        success: Bool,
        detail: String? = nil
    ) {
        self.action = action
        self.nodeOid = nodeOid
        self.targetClass = targetClass
        self.mode = mode
        self.success = success
        self.detail = detail
    }
}
