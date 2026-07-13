import Foundation

public struct LKCoordinateSemanticSwipeResponse: Equatable, Sendable {
    public let detail: String?
    public let strategy: String?
    public let startX: Double?
    public let startY: Double?
    public let endX: Double?
    public let endY: Double?
    public let hitOid: UInt?
    public let hitClass: String?

    public init(
        detail: String? = nil,
        strategy: String? = nil,
        startX: Double? = nil,
        startY: Double? = nil,
        endX: Double? = nil,
        endY: Double? = nil,
        hitOid: UInt? = nil,
        hitClass: String? = nil
    ) {
        self.detail = detail
        self.strategy = strategy
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
        self.hitOid = hitOid
        self.hitClass = hitClass
    }
}
