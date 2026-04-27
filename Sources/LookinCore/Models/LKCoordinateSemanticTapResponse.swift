import Foundation

public struct LKCoordinateSemanticTapResponse: Equatable, Sendable {
    public let detail: String?
    public let strategy: String?
    public let x: Double?
    public let y: Double?
    public let hitOid: UInt?
    public let hitClass: String?

    public init(
        detail: String? = nil,
        strategy: String? = nil,
        x: Double? = nil,
        y: Double? = nil,
        hitOid: UInt? = nil,
        hitClass: String? = nil
    ) {
        self.detail = detail
        self.strategy = strategy
        self.x = x
        self.y = y
        self.hitOid = hitOid
        self.hitClass = hitClass
    }
}
