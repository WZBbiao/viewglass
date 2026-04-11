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
        /// When true, setAttribute will also send UIControlEventValueChanged
        /// after the property is written so app-layer callbacks fire.
        public let sendsValueChanged: Bool

        public init(
            _ setter: String,
            _ getter: String,
            _ attrType: LookinAttrType,
            layer: Bool = false,
            requiredClass: String? = nil,
            sendsValueChanged: Bool = false
        ) {
            self.setter = setter
            self.getter = getter
            self.attrType = attrType
            self.targetIsLayer = layer
            self.requiredClass = requiredClass
            self.sendsValueChanged = sendsValueChanged
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
        "selected":              AttributeMapping("setSelected:", "isSelected", .BOOL, requiredClass: "UIControl", sendsValueChanged: true),
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

        // UISwitch
        "isOn":                  AttributeMapping("setOn:", "isOn", .BOOL, requiredClass: "UISwitch", sendsValueChanged: true),

        // UISegmentedControl
        "selectedSegmentIndex":  AttributeMapping("setSelectedSegmentIndex:", "selectedSegmentIndex", .long, requiredClass: "UISegmentedControl", sendsValueChanged: true),
    ]

    /// Look up the mapping for a user-friendly key.
    public static func mapping(for key: String) -> AttributeMapping? {
        mappings[key]
    }

    /// List all available attribute keys.
    public static var allKeys: [String] {
        mappings.keys.sorted()
    }

    // MARK: - Obfuscated Identifier → Readable Name

    /// Maps Lookin's internal short attribute identifiers (e.g. "sv_o_o") to
    /// human-readable names (e.g. "contentOffset") for AI-agent–friendly output.
    private static let attrIdentifierReadableNames: [String: String] = [
        // Layout
        "l_f_f": "frame",
        "l_b_b": "bounds",
        "l_s_s": "safeAreaInsets",
        "l_p_p": "layer.position",
        "l_a_a": "layer.anchorPoint",

        // AutoLayout
        "al_h_h": "contentHugging.horizontal",
        "al_h_v": "contentHugging.vertical",
        "al_r_h": "compressionResistance.horizontal",
        "al_r_v": "compressionResistance.vertical",
        "al_c_c": "constraints",
        "cl_i_s": "intrinsicContentSize",

        // View & Layer – visibility
        "vl_v_h": "hidden",
        "vl_v_o": "opacity",

        // View & Layer – interaction / masks
        "vl_i_i": "userInteractionEnabled",
        "vl_i_m": "masksToBounds",

        // View & Layer – corner / border / shadow
        "vl_c_r": "cornerRadius",
        "vl_b_b": "backgroundColor",
        "vl_b_c": "borderColor",
        "vl_b_w": "borderWidth",
        "vl_s_c": "shadowColor",
        "vl_s_o": "shadowOpacity",
        "vl_s_r": "shadowRadius",
        "vl_s_ow": "shadowOffset.width",
        "vl_s_oh": "shadowOffset.height",

        // View & Layer – appearance
        "vl_c_m": "contentMode",
        "vl_t_c": "tintColor",
        "vl_t_m": "tintAdjustmentMode",
        "vl_t_t": "tag",

        // UIImageView
        "iv_n_n": "imageName",
        "iv_o_o": "image",

        // UILabel
        "lb_t_t": "text",
        "lb_f_n": "fontName",
        "lb_f_s": "fontSize",
        "lb_n_n": "numberOfLines",
        "lb_t_c": "textColor",
        "lb_a_a": "textAlignment",
        "lb_b_m": "lineBreakMode",
        "lb_c_c": "adjustsFontSizeToFit",

        // UIControl
        "ct_e_e": "enabled",
        "ct_e_s": "selected",
        "ct_v_a": "contentVerticalAlignment",
        "ct_h_a": "contentHorizontalAlignment",

        // UIButton
        "bt_c_i": "contentEdgeInsets",
        "bt_t_i": "titleEdgeInsets",
        "bt_i_i": "imageEdgeInsets",

        // UIScrollView
        "sv_o_o": "contentOffset",
        "sv_c_s": "contentSize",
        "sv_c_i": "contentInset",
        "sv_a_i": "adjustedContentInset",
        "sv_b_b": "contentInsetAdjustmentBehavior",
        "sv_i_i": "scrollIndicatorInsets",
        "sv_s_s": "scrollEnabled",
        "sv_s_p": "pagingEnabled",
        "sv_b_v": "alwaysBounceVertical",
        "sv_b_h": "alwaysBounceHorizontal",
        "sv_h_h": "showsHorizontalScrollIndicator",
        "sv_s_v": "showsVerticalScrollIndicator",
        "sv_c_d": "delaysContentTouches",
        "sv_c_c": "canCancelContentTouches",
        "sv_z_mi": "minimumZoomScale",
        "sv_z_ma": "maximumZoomScale",
        "sv_z_s": "zoomScale",
        "sv_z_b": "bouncesZoom",

        // UITableView
        "tv_s_s": "tableStyle",
        "tv_s_n": "numberOfSections",
        "tv_r_n": "totalRows",
        "tv_s_i": "separatorInset",
        "tv_s_c": "separatorColor",
        "tv_ss_s": "separatorStyle",

        // UITextView
        "te_f_n": "textView.fontName",
        "te_f_s": "textView.fontSize",
        "te_b_e": "isEditable",
        "te_b_s": "isSelectable",
        "te_t_t": "textView.text",
        "te_t_c": "textView.textColor",
        "te_a_a": "textView.textAlignment",
        "te_c_i": "textContainerInset",

        // UITextField
        "tf_t_t": "textField.text",
        "tf_p_p": "placeholder",
        "tf_f_n": "textField.fontName",
        "tf_f_s": "textField.fontSize",
        "tf_t_c": "textField.textColor",
        "tf_a_a": "textField.textAlignment",
        "tf_c_c": "clearsOnBeginEditing",
        "tf_c_co": "clearsOnInsertion",
        "tf_c_ca": "adjustsFontSizeToFit",
        "tf_c_m": "minimumFontSize",
        "tf_cb_m": "clearButtonMode",

        // UIVisualEffectView
        "ve_s_s": "blurEffectStyle",

        // UIStackView
        "usv_axis_axis": "axis",
        "usv_dis_dis": "distribution",
        "usv_ali_ali": "stackAlignment",
        "usv_spa_spa": "spacing",
    ]

    /// Returns a human-readable name for a Lookin short attribute identifier,
    /// or nil if the identifier is not recognized.
    public static func readableName(forAttrIdentifier id: String) -> String? {
        attrIdentifierReadableNames[id]
    }

    // MARK: - Enum Integer → Name Mapping

    /// Maps readable attribute key names (post-resolution) that carry UIKit enum integers
    /// to dictionaries of int value → human-readable string (e.g. "contentMode" 2 → "scaleAspectFill").
    private static let enumNames: [String: [Int: String]] = [
        "contentMode": [
            0: "scaleToFill",
            1: "scaleAspectFit",
            2: "scaleAspectFill",
            3: "redraw",
            4: "center",
            5: "top",
            6: "bottom",
            7: "left",
            8: "right",
            9: "topLeft",
            10: "topRight",
            11: "bottomLeft",
            12: "bottomRight",
        ],
        "textAlignment": [
            0: "left",
            1: "center",
            2: "right",
            3: "justified",
            4: "natural",
        ],
        "lineBreakMode": [
            0: "wordWrap",
            1: "charWrap",
            2: "clip",
            3: "truncatingHead",
            4: "truncatingTail",
            5: "truncatingMiddle",
        ],
        "axis": [
            0: "horizontal",
            1: "vertical",
        ],
        "alignment": [      // UIStackView.Alignment
            0: "fill",
            1: "leading",
            2: "firstBaseline",
            3: "center",
            4: "trailing",
            5: "lastBaseline",
        ],
        "stackAlignment": [
            0: "fill",
            1: "leading",
            2: "firstBaseline",
            3: "center",
            4: "trailing",
            5: "lastBaseline",
        ],
        "distribution": [   // UIStackView.Distribution
            0: "fill",
            1: "fillEqually",
            2: "fillProportionally",
            3: "equalSpacing",
            4: "equalCentering",
        ],
        "contentVerticalAlignment": [
            0: "center",
            1: "top",
            2: "bottom",
            3: "fill",
        ],
        "contentHorizontalAlignment": [
            0: "center",
            1: "left",
            2: "right",
            3: "fill",
            4: "leading",
            5: "trailing",
        ],
    ]

    /// Returns the human-readable name for a UIKit enum integer value at the given
    /// readable attribute key, or nil if no mapping exists.
    public static func enumName(forKey key: String, intValue: Int) -> String? {
        enumNames[key]?[intValue]
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
