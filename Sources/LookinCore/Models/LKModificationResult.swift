import Foundation

public struct LKModificationResult: Codable, Equatable, Sendable {
    public let nodeOid: UInt
    public let attributeKey: String
    public let previousValue: String
    public let newValue: String
    public let success: Bool
    public let error: String?

    public init(
        nodeOid: UInt,
        attributeKey: String,
        previousValue: String,
        newValue: String,
        success: Bool = true,
        error: String? = nil
    ) {
        self.nodeOid = nodeOid
        self.attributeKey = attributeKey
        self.previousValue = previousValue
        self.newValue = newValue
        self.success = success
        self.error = error
    }
}
