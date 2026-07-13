import Foundation
import CoreGraphics

/// Direction for a semantic swipe gesture.
public enum LKSwipeDirection: String, CaseIterable, Codable, Sendable {
    case up
    case down
    case left
    case right

    /// Human-readable axis description for this direction.
    public var scrollAxisDescription: String {
        switch self {
        case .up:    return "scroll down (contentOffset.y +)"
        case .down:  return "scroll up (contentOffset.y -)"
        case .left:  return "scroll right (contentOffset.x +)"
        case .right: return "scroll left (contentOffset.x -)"
        }
    }

    public func endPoint(from startPoint: CGPoint, distance: CGFloat) -> CGPoint {
        switch self {
        case .up:
            return CGPoint(x: startPoint.x, y: startPoint.y - distance)
        case .down:
            return CGPoint(x: startPoint.x, y: startPoint.y + distance)
        case .left:
            return CGPoint(x: startPoint.x - distance, y: startPoint.y)
        case .right:
            return CGPoint(x: startPoint.x + distance, y: startPoint.y)
        }
    }
}
