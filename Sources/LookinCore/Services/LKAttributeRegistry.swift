import Foundation
import LookinSharedBridge

/// Maps user-friendly attribute keys to LookinAttributeModification parameters.
public enum LKAttributeRegistry {

    public struct AttributeMapping {
        public let setter: String      // ObjC setter selector string
        public let getter: String      // ObjC getter selector string
        public let attrType: LookinAttrType
        public let targetIsLayer: Bool // true = layer OID, false = view OID
        public let requiredClass: String?

        public init(
            _ setter: String,
            _ getter: String,
            _ attrType: LookinAttrType,
            layer: Bool = false,
            requiredClass: String? = nil
        ) {
            self.setter = setter
            self.getter = getter
            self.attrType = attrType
            self.targetIsLayer = layer
            self.requiredClass = requiredClass
        }
    }

    // MARK: - Attribute Mappings

    private static let mappings: [String: AttributeMapping] = [
        // View visibility
        "alpha":                 AttributeMapping("setAlpha:", "alpha", .float),
        "hidden":                AttributeMapping("setHidden:", "isHidden", .BOOL),
        "opaque":                AttributeMapping("setOpaque:", "isOpaque", .BOOL),
        "clipsToBounds":         AttributeMapping("setClipsToBounds:", "clipsToBounds", .BOOL),
        "userInteractionEnabled":AttributeMapping("setUserInteractionEnabled:", "isUserInteractionEnabled", .BOOL),

        // Layer properties
        "opacity":               AttributeMapping("setOpacity:", "opacity", .float, layer: true),
        "cornerRadius":          AttributeMapping("setCornerRadius:", "cornerRadius", .double, layer: true),
        "borderWidth":           AttributeMapping("setBorderWidth:", "borderWidth", .double, layer: true),
        "borderColor":           AttributeMapping("setBorderColor:", "borderColor", .uiColor, layer: true),
        "shadowOpacity":         AttributeMapping("setShadowOpacity:", "shadowOpacity", .float, layer: true),
        "shadowRadius":          AttributeMapping("setShadowRadius:", "shadowRadius", .double, layer: true),
        "masksToBounds":         AttributeMapping("setMasksToBounds:", "masksToBounds", .BOOL, layer: true),

        // Geometry
        "frame":                 AttributeMapping("setFrame:", "frame", .cgRect),
        "bounds":                AttributeMapping("setBounds:", "bounds", .cgRect),
        "center":                AttributeMapping("setCenter:", "center", .cgPoint),
        "transform":             AttributeMapping("setTransform:", "transform", .cgAffineTransform),

        // View appearance
        "backgroundColor":       AttributeMapping("setBackgroundColor:", "backgroundColor", .uiColor),
        "tintColor":             AttributeMapping("setTintColor:", "tintColor", .uiColor),
        "contentMode":           AttributeMapping("setContentMode:", "contentMode", .enumInt),
        "tag":                   AttributeMapping("setTag:", "tag", .long),

        // UILabel
        "text":                  AttributeMapping("setText:", "text", .nsString, requiredClass: "UILabel"),
        "numberOfLines":         AttributeMapping("setNumberOfLines:", "numberOfLines", .long),
        "textAlignment":         AttributeMapping("setTextAlignment:", "textAlignment", .enumInt),
        "lineBreakMode":         AttributeMapping("setLineBreakMode:", "lineBreakMode", .enumInt),
        "textColor":             AttributeMapping("setTextColor:", "textColor", .uiColor, requiredClass: "UILabel"),

        // UIButton
        "enabled":               AttributeMapping("setEnabled:", "isEnabled", .BOOL, requiredClass: "UIControl"),
        "selected":              AttributeMapping("setSelected:", "isSelected", .BOOL, requiredClass: "UIControl"),
        "highlighted":           AttributeMapping("setHighlighted:", "isHighlighted", .BOOL, requiredClass: "UIControl"),

        // UITextField
        "placeholder":           AttributeMapping("setPlaceholder:", "placeholder", .nsString, requiredClass: "UITextField"),

        // UIScrollView
        "contentOffset":         AttributeMapping("setContentOffset:", "contentOffset", .cgPoint, requiredClass: "UIScrollView"),
        "contentSize":           AttributeMapping("setContentSize:", "contentSize", .cgSize, requiredClass: "UIScrollView"),
        "contentInset":          AttributeMapping("setContentInset:", "contentInset", .uiEdgeInsets, requiredClass: "UIScrollView"),
        "scrollEnabled":         AttributeMapping("setScrollEnabled:", "isScrollEnabled", .BOOL, requiredClass: "UIScrollView"),
        "pagingEnabled":         AttributeMapping("setPagingEnabled:", "isPagingEnabled", .BOOL, requiredClass: "UIScrollView"),
        "bounces":               AttributeMapping("setBounces:", "bounces", .BOOL, requiredClass: "UIScrollView"),
        "zoomScale":             AttributeMapping("setZoomScale:", "zoomScale", .double, requiredClass: "UIScrollView"),
        "minimumZoomScale":      AttributeMapping("setMinimumZoomScale:", "minimumZoomScale", .double, requiredClass: "UIScrollView"),
        "maximumZoomScale":      AttributeMapping("setMaximumZoomScale:", "maximumZoomScale", .double, requiredClass: "UIScrollView"),
        "bouncesZoom":           AttributeMapping("setBouncesZoom:", "bouncesZoom", .BOOL, requiredClass: "UIScrollView"),

        // UIStackView
        "spacing":               AttributeMapping("setSpacing:", "spacing", .double, requiredClass: "UIStackView"),
        "axis":                  AttributeMapping("setAxis:", "axis", .enumInt, requiredClass: "UIStackView"),
        "alignment":             AttributeMapping("setAlignment:", "alignment", .enumInt, requiredClass: "UIStackView"),
        "distribution":          AttributeMapping("setDistribution:", "distribution", .enumInt, requiredClass: "UIStackView"),

        // UIImageView
        "contentScaleFactor":    AttributeMapping("setContentScaleFactor:", "contentScaleFactor", .double),
    ]

    /// Look up the mapping for a user-friendly key.
    public static func mapping(for key: String) -> AttributeMapping? {
        mappings[key]
    }

    /// List all available attribute keys.
    public static var allKeys: [String] {
        mappings.keys.sorted()
    }

    // MARK: - Value Parsing

    /// Parse a string value into the appropriate NSObject for the given attribute type.
    public static func parseValue(_ string: String, attrType: LookinAttrType) -> NSObject? {
        switch attrType {
        case .BOOL:
            return parseBool(string) as NSNumber?
        case .char, .int, .short, .long, .unsignedChar, .unsignedInt, .unsignedShort, .unsignedLong:
            return parseInt(string) as NSNumber?
        case .longLong, .unsignedLongLong:
            return parseLongLong(string) as NSNumber?
        case .float:
            return parseFloat(string) as NSNumber?
        case .double:
            return parseDouble(string) as NSNumber?
        case .cgRect:
            return parseRect(string)
        case .cgPoint:
            return parsePoint(string)
        case .cgSize:
            return parseSize(string)
        case .uiEdgeInsets:
            return parseInsets(string)
        case .nsString:
            return string as NSString
        case .uiColor:
            return parseColor(string) as NSObject?
        case .enumInt:
            return parseInt(string) as NSNumber?
        case .enumLong:
            return parseLongLong(string) as NSNumber?
        default:
            // Try as a generic string
            return string as NSString
        }
    }

    // MARK: - Parsers

    private static func parseBool(_ s: String) -> NSNumber? {
        switch s.lowercased() {
        case "true", "yes", "1": return NSNumber(value: true)
        case "false", "no", "0": return NSNumber(value: false)
        default: return nil
        }
    }

    private static func parseInt(_ s: String) -> NSNumber? {
        guard let v = Int(s) else { return nil }
        return NSNumber(value: v)
    }

    private static func parseLongLong(_ s: String) -> NSNumber? {
        guard let v = Int64(s) else { return nil }
        return NSNumber(value: v)
    }

    private static func parseFloat(_ s: String) -> NSNumber? {
        guard let v = Float(s) else { return nil }
        return NSNumber(value: v)
    }

    private static func parseDouble(_ s: String) -> NSNumber? {
        guard let v = Double(s) else { return nil }
        return NSNumber(value: v)
    }

    private static func parseRect(_ s: String) -> NSValue? {
        let nums = s.components(separatedBy: CharacterSet(charactersIn: "{}, "))
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count == 4 else { return nil }
        let rect = NSRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
        return NSValue(rect: rect)
    }

    private static func parsePoint(_ s: String) -> NSValue? {
        let nums = s.components(separatedBy: CharacterSet(charactersIn: "{}, "))
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count == 2 else { return nil }
        let point = NSPoint(x: nums[0], y: nums[1])
        return NSValue(point: point)
    }

    private static func parseSize(_ s: String) -> NSValue? {
        let nums = s.components(separatedBy: CharacterSet(charactersIn: "{}, "))
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count == 2 else { return nil }
        let size = NSSize(width: nums[0], height: nums[1])
        return NSValue(size: size)
    }

    private static func parseInsets(_ s: String) -> NSValue? {
        let nums = s.components(separatedBy: CharacterSet(charactersIn: "{}, "))
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count == 4 else { return nil }
        let insets = NSEdgeInsets(top: nums[0], left: nums[1], bottom: nums[2], right: nums[3])
        return NSValue(edgeInsets: insets)
    }

    /// Parse color from "#RRGGBB", "#RRGGBBAA", "r,g,b", or "r,g,b,a" (0-255).
    /// Returns NSArray of [R, G, B, A] (0.0-1.0) for Lookin protocol.
    private static func parseColor(_ s: String) -> NSArray? {
        if s.hasPrefix("#") {
            return parseHexColor(s)
        }
        // Comma-separated: "255,0,0" or "255,0,0,128"
        let parts = s.components(separatedBy: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 3 {
            return [parts[0] / 255.0, parts[1] / 255.0, parts[2] / 255.0, 1.0] as NSArray
        } else if parts.count == 4 {
            return [parts[0] / 255.0, parts[1] / 255.0, parts[2] / 255.0, parts[3] / 255.0] as NSArray
        }
        return nil
    }

    private static func parseHexColor(_ hex: String) -> NSArray? {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6 || h.count == 8 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r, g, b, a: Double
        if h.count == 8 {
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        } else {
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1.0
        }
        return [r, g, b, a] as NSArray
    }
}
