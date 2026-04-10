import Foundation

/// Compact node representation for AI agent consumption.
/// Serialises as `{"oid":4,"class":"UIButton","frame":[x,y,w,h],"label":"Submit"}`.
/// Omits `hidden` when false and `children` when empty to minimise token usage.
public struct LKCompactSnapshot: Codable, Sendable {
    public let app: String
    public let nodeCount: Int
    public let nodes: [LKCompactNode]

    public init(app: String, nodeCount: Int, nodes: [LKCompactNode]) {
        self.app = app
        self.nodeCount = nodeCount
        self.nodes = nodes
    }
}

public struct LKCompactNode: Codable, Sendable {
    public let oid: UInt
    public let className: String
    public let frame: [Int]          // [x, y, width, height]
    public let label: String?        // accessibilityLabel or customDisplayTitle
    public let a11yId: String?       // accessibilityIdentifier
    public let hidden: Bool?         // only present (=true) when node is not visible
    public let children: [LKCompactNode]?  // only present when non-empty

    public init(oid: UInt, className: String, frame: [Int], label: String?,
                a11yId: String?, hidden: Bool?, children: [LKCompactNode]?) {
        self.oid = oid; self.className = className; self.frame = frame
        self.label = label; self.a11yId = a11yId; self.hidden = hidden; self.children = children
    }

    // Serialise `className` as "class" and omit nil/false fields entirely.
    enum CodingKeys: String, CodingKey {
        case oid, frame, label, a11yId, hidden, children
        case className = "class"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(oid, forKey: .oid)
        try c.encode(className, forKey: .className)
        try c.encode(frame, forKey: .frame)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(a11yId, forKey: .a11yId)
        if hidden == true { try c.encode(true, forKey: .hidden) }
        if let ch = children, !ch.isEmpty { try c.encode(ch, forKey: .children) }
    }
}
