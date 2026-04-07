import Foundation

public struct LKAttributeGroup: Codable, Equatable, Sendable {
    public let groupName: String
    public let attributes: [LKAttribute]

    public init(groupName: String, attributes: [LKAttribute]) {
        self.groupName = groupName
        self.attributes = attributes
    }
}

public struct LKAttribute: Codable, Equatable, Sendable {
    public let key: String
    public let displayName: String
    public let value: LKAttributeValue
    public let isReadonly: Bool

    public init(
        key: String,
        displayName: String,
        value: LKAttributeValue,
        isReadonly: Bool = false
    ) {
        self.key = key
        self.displayName = displayName
        self.value = value
        self.isReadonly = isReadonly
    }
}

public enum LKAttributeValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case rect(LKRect)
    case color(String)
    case null

    public var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return "\(n)"
        case .bool(let b): return b ? "true" : "false"
        case .rect(let r): return "(\(r.x), \(r.y), \(r.width), \(r.height))"
        case .color(let c): return c
        case .null: return "nil"
        }
    }
}
