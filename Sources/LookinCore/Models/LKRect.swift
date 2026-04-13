import Foundation

public struct LKRect: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var area: Double { width * height }

    public func intersects(_ other: LKRect) -> Bool {
        let left = max(x, other.x)
        let top = max(y, other.y)
        let right = min(x + width, other.x + other.width)
        let bottom = min(y + height, other.y + other.height)
        return left < right && top < bottom
    }

    public func intersection(_ other: LKRect) -> LKRect? {
        let left = max(x, other.x)
        let top = max(y, other.y)
        let right = min(x + width, other.x + other.width)
        let bottom = min(y + height, other.y + other.height)
        guard left < right && top < bottom else { return nil }
        return LKRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    public func contains(_ other: LKRect) -> Bool {
        other.x >= x && other.y >= y &&
        other.x + other.width <= x + width &&
        other.y + other.height <= y + height
    }

    public func contains(point: (x: Double, y: Double)) -> Bool {
        point.x >= x && point.x <= x + width &&
        point.y >= y && point.y <= y + height
    }
}
