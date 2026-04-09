import Foundation

public enum LKNodeOIDType: String, Codable, Equatable, Sendable {
    case view
    case layer
    case controller
    case unknown
}

public struct LKNode: Codable, Equatable, Sendable {
    public let oid: UInt
    public let primaryOid: UInt
    public let oidType: LKNodeOIDType
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
    public let hostViewControllerClassName: String?
    public let hostViewControllerOid: UInt?
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

    enum CodingKeys: String, CodingKey {
        case oid
        case primaryOid
        case oidType
        case viewOid
        case layerOid
        case className
        case address
        case frame
        case bounds
        case isHidden
        case alpha
        case isUserInteractionEnabled
        case backgroundColor
        case tag
        case accessibilityLabel
        case accessibilityIdentifier
        case hostViewControllerClassName
        case hostViewControllerOid
        case layerClassName
        case clipsToBounds
        case isOpaque
        case contentMode
        case customDisplayTitle
        case depth
        case parentOid
        case childrenOids
        case attributeGroups
    }

    public init(
        oid: UInt,
        primaryOid: UInt? = nil,
        oidType: LKNodeOIDType = .unknown,
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
        hostViewControllerClassName: String? = nil,
        hostViewControllerOid: UInt? = nil,
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
        self.primaryOid = primaryOid ?? viewOid ?? layerOid ?? oid
        self.oidType = oidType
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
        self.hostViewControllerClassName = hostViewControllerClassName
        self.hostViewControllerOid = hostViewControllerOid
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let oid = try container.decode(UInt.self, forKey: .oid)
        let viewOid = try container.decodeIfPresent(UInt.self, forKey: .viewOid)
        let layerOid = try container.decodeIfPresent(UInt.self, forKey: .layerOid)

        self.oid = oid
        self.primaryOid = try container.decodeIfPresent(UInt.self, forKey: .primaryOid) ?? viewOid ?? layerOid ?? oid
        self.oidType = try container.decodeIfPresent(LKNodeOIDType.self, forKey: .oidType)
            ?? (layerOid == oid ? .layer : (viewOid == oid ? .view : .unknown))
        self.viewOid = viewOid
        self.layerOid = layerOid
        self.className = try container.decode(String.self, forKey: .className)
        self.address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        self.frame = try container.decodeIfPresent(LKRect.self, forKey: .frame) ?? LKRect(x: 0, y: 0, width: 0, height: 0)
        self.bounds = try container.decodeIfPresent(LKRect.self, forKey: .bounds) ?? LKRect(x: 0, y: 0, width: 0, height: 0)
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.alpha = try container.decodeIfPresent(Double.self, forKey: .alpha) ?? 1.0
        self.isUserInteractionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isUserInteractionEnabled) ?? true
        self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        self.tag = try container.decodeIfPresent(Int.self, forKey: .tag) ?? 0
        self.accessibilityLabel = try container.decodeIfPresent(String.self, forKey: .accessibilityLabel)
        self.accessibilityIdentifier = try container.decodeIfPresent(String.self, forKey: .accessibilityIdentifier)
        self.hostViewControllerClassName = try container.decodeIfPresent(String.self, forKey: .hostViewControllerClassName)
        self.hostViewControllerOid = try container.decodeIfPresent(UInt.self, forKey: .hostViewControllerOid)
        self.layerClassName = try container.decodeIfPresent(String.self, forKey: .layerClassName)
        self.clipsToBounds = try container.decodeIfPresent(Bool.self, forKey: .clipsToBounds) ?? false
        self.isOpaque = try container.decodeIfPresent(Bool.self, forKey: .isOpaque) ?? true
        self.contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)
        self.customDisplayTitle = try container.decodeIfPresent(String.self, forKey: .customDisplayTitle)
        self.depth = try container.decodeIfPresent(Int.self, forKey: .depth) ?? 0
        self.parentOid = try container.decodeIfPresent(UInt.self, forKey: .parentOid)
        self.childrenOids = try container.decodeIfPresent([UInt].self, forKey: .childrenOids) ?? []
        self.attributeGroups = try container.decodeIfPresent([LKAttributeGroup].self, forKey: .attributeGroups)
    }
}
