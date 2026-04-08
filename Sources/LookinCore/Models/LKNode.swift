import Foundation

public struct LKNode: Codable, Equatable, Sendable {
    public let oid: UInt
    public let viewOid: UInt?
    public let layerOid: UInt?
    public let className: String
    public let address: String
    public let frame: LKRect
    public let bounds: LKRect
    public let isHidden: Bool
    public let alpha: Double
    public let isUserInteractionEnabled: Bool
    public let backgroundColor: String?
    public let tag: Int
    public let accessibilityLabel: String?
    public let accessibilityIdentifier: String?
    public let layerClassName: String?
    public let clipsToBounds: Bool
    public let isOpaque: Bool
    public let contentMode: String?
    public let customDisplayTitle: String?
    public let depth: Int
    public let parentOid: UInt?
    public let childrenOids: [UInt]
    public let attributeGroups: [LKAttributeGroup]?

    public var isVisible: Bool {
        !isHidden && alpha > 0 && bounds.width > 0 && bounds.height > 0
    }

    public var displayTitle: String {
        customDisplayTitle ?? className
    }

    public init(
        oid: UInt,
        viewOid: UInt? = nil,
        layerOid: UInt? = nil,
        className: String,
        address: String = "",
        frame: LKRect = LKRect(x: 0, y: 0, width: 0, height: 0),
        bounds: LKRect = LKRect(x: 0, y: 0, width: 0, height: 0),
        isHidden: Bool = false,
        alpha: Double = 1.0,
        isUserInteractionEnabled: Bool = true,
        backgroundColor: String? = nil,
        tag: Int = 0,
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        layerClassName: String? = nil,
        clipsToBounds: Bool = false,
        isOpaque: Bool = true,
        contentMode: String? = nil,
        customDisplayTitle: String? = nil,
        depth: Int = 0,
        parentOid: UInt? = nil,
        childrenOids: [UInt] = [],
        attributeGroups: [LKAttributeGroup]? = nil
    ) {
        self.oid = oid
        self.viewOid = viewOid
        self.layerOid = layerOid
        self.className = className
        self.address = address
        self.frame = frame
        self.bounds = bounds
        self.isHidden = isHidden
        self.alpha = alpha
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.backgroundColor = backgroundColor
        self.tag = tag
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.layerClassName = layerClassName
        self.clipsToBounds = clipsToBounds
        self.isOpaque = isOpaque
        self.contentMode = contentMode
        self.customDisplayTitle = customDisplayTitle
        self.depth = depth
        self.parentOid = parentOid
        self.childrenOids = childrenOids
        self.attributeGroups = attributeGroups
    }
}
