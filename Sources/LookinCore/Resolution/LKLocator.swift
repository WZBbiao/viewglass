import Foundation

public enum LKLocatorKind: String, Codable, Equatable, Sendable {
    case oid
    case primaryOid
    case accessibilityIdentifier
    case accessibilityLabel
    case controller
    case query
}

public struct LKLocator: Codable, Equatable, Sendable {
    public let rawValue: String
    public let kind: LKLocatorKind
    public let value: String

    public init(rawValue: String, kind: LKLocatorKind, value: String) {
        self.rawValue = rawValue
        self.kind = kind
        self.value = value
    }

    public static func parse(_ input: String) -> LKLocator {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) {
            return LKLocator(rawValue: input, kind: .oid, value: trimmed)
        }
        if trimmed.hasPrefix("primaryOid:") {
            return LKLocator(rawValue: input, kind: .primaryOid, value: String(trimmed.dropFirst("primaryOid:".count)))
        }
        if trimmed.hasPrefix("oid:") {
            return LKLocator(rawValue: input, kind: .oid, value: String(trimmed.dropFirst(4)))
        }
        if trimmed.hasPrefix("#") {
            return LKLocator(rawValue: input, kind: .accessibilityIdentifier, value: String(trimmed.dropFirst()))
        }
        if trimmed.hasPrefix("@\""), trimmed.hasSuffix("\"") {
            return LKLocator(rawValue: input, kind: .accessibilityLabel, value: String(trimmed.dropFirst(2).dropLast()))
        }
        if trimmed.hasPrefix("@") {
            return LKLocator(rawValue: input, kind: .accessibilityLabel, value: String(trimmed.dropFirst()))
        }
        if trimmed.hasPrefix("controller:") {
            return LKLocator(rawValue: input, kind: .controller, value: String(trimmed.dropFirst("controller:".count)))
        }
        // Strings with logical operators are query expressions, not label searches.
        let upper = trimmed.uppercased()
        let isQueryExpression = upper.contains(" AND ") || upper.contains(" OR ")
            || upper.hasPrefix("NOT ") || trimmed.contains("(")
        if !isQueryExpression && trimmed.contains(" ") {
            // Strings containing spaces are unlikely to be class names — treat them as
            // accessibilityLabel searches so `locate "Open Long Feed"` works intuitively.
            return LKLocator(rawValue: input, kind: .accessibilityLabel, value: trimmed)
        }
        return LKLocator(rawValue: input, kind: .query, value: trimmed)
    }
}
