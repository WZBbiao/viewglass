import Foundation

/// Result of a `wait appears` or `wait gone` polling operation.
public struct LKWaitResult: Codable, Sendable {
    /// Human-readable description of the polled condition.
    public let condition: String
    /// Whether the condition was satisfied before the timeout elapsed.
    public let met: Bool
    /// Wall-clock time elapsed from first poll to completion (seconds).
    public let elapsedSeconds: Double
    /// Number of poll iterations executed.
    public let pollCount: Int
    /// Final match count from the last poll (nil if not applicable).
    public let matchCount: Int?

    public init(condition: String, met: Bool, elapsedSeconds: Double, pollCount: Int, matchCount: Int? = nil) {
        self.condition = condition
        self.met = met
        self.elapsedSeconds = elapsedSeconds
        self.pollCount = pollCount
        self.matchCount = matchCount
    }
}
