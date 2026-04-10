import Foundation

/// Direction for a semantic swipe gesture on a UIScrollView.
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
}
