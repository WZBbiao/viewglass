import Foundation
import LookinSharedBridge

/// Converts LookinSharedBridge ObjC types to LookinCore Swift DTOs.
public enum LKBridgeConverter {

    public static func convertAppInfo(_ info: LookinAppInfo, port: Int, deviceType: LKAppDescriptor.DeviceType) -> LKAppDescriptor {
        LKAppDescriptor(
            appName: info.appName ?? "Unknown",
            bundleIdentifier: info.appBundleIdentifier ?? "unknown",
            appVersion: nil,
            deviceName: info.deviceDescription,
            deviceType: deviceType,
            port: port,
            serverVersion: info.serverReadableVersion
        )
    }

    public static func convertHierarchy(_ info: LookinHierarchyInfo, app: LKAppDescriptor) -> LKHierarchySnapshot {
        let windows = (info.displayItems ?? []).map { item in
            convertDisplayItemTree(item, depth: 0, parentOid: nil)
        }

        let screenSize = LKRect(
            x: 0, y: 0,
            width: info.appInfo?.screenWidth ?? 390,
            height: info.appInfo?.screenHeight ?? 844
        )

        return LKHierarchySnapshot(
            appInfo: app,
            windows: windows,
            fetchedAt: Date(),
            serverVersion: info.appInfo?.serverReadableVersion,
            screenScale: info.appInfo?.screenScale ?? 2.0,
            screenSize: screenSize
        )
    }

    public static func convertDisplayItemTree(
        _ item: LookinDisplayItem,
        depth: Int,
        parentOid: UInt?
    ) -> LKNodeTree {
        let node = convertDisplayItem(item, depth: depth, parentOid: parentOid)
        let children = (item.subitems ?? []).map { child in
            convertDisplayItemTree(child, depth: depth + 1, parentOid: node.oid)
        }
        return LKNodeTree(node: node, children: children)
    }

    public static func convertDisplayItem(
        _ item: LookinDisplayItem,
        depth: Int,
        parentOid: UInt?
    ) -> LKNode {
        let viewOid = item.viewObject?.oid
        let layerOid = item.layerObject?.oid
        let oid = layerOid ?? viewOid ?? 0
        let className = item.viewObject?.rawClassName() ?? item.layerObject?.rawClassName() ?? "Unknown"
        let address = item.viewObject?.memoryAddress ?? item.layerObject?.memoryAddress ?? ""

        let frame = LKRect(
            x: Double(item.frame.origin.x),
            y: Double(item.frame.origin.y),
            width: Double(item.frame.size.width),
            height: Double(item.frame.size.height)
        )
        let bounds = LKRect(
            x: Double(item.bounds.origin.x),
            y: Double(item.bounds.origin.y),
            width: Double(item.bounds.size.width),
            height: Double(item.bounds.size.height)
        )

        let childrenOids = (item.subitems ?? []).compactMap { child -> UInt? in
            child.layerObject?.oid ?? child.viewObject?.oid
        }

        let attrGroups = item.attributesGroupList?.map { convertAttributesGroup($0) }

        // Extract tag, accessibility, and interaction info from attribute groups
        let tag = extractIntAttribute("tag", from: item.attributesGroupList)
        let accessibilityLabel = extractStringAttribute("accessibilityLabel", from: item.attributesGroupList)
        let accessibilityIdentifier = extractStringAttribute("accessibilityIdentifier", from: item.attributesGroupList)
        let isUserInteractionEnabled = extractBoolAttribute("userInteractionEnabled", from: item.attributesGroupList) ?? true

        return LKNode(
            oid: UInt(oid),
            viewOid: viewOid.map { UInt($0) },
            layerOid: layerOid.map { UInt($0) },
            className: className,
            address: address,
            frame: frame,
            bounds: bounds,
            isHidden: item.isHidden,
            alpha: Double(item.alpha),
            isUserInteractionEnabled: isUserInteractionEnabled,
            tag: tag ?? 0,
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            customDisplayTitle: item.customDisplayTitle,
            depth: depth,
            parentOid: parentOid,
            childrenOids: childrenOids.map { UInt($0) },
            attributeGroups: attrGroups
        )
    }

    public static func convertAttributesGroup(_ group: LookinAttributesGroup) -> LKAttributeGroup {
        let attrs = (group.attrSections ?? []).flatMap { section in
            (section.attributes ?? []).map { convertAttribute($0) }
        }
        let name = group.userCustomTitle ?? group.identifier ?? "Unknown"
        return LKAttributeGroup(groupName: name, attributes: attrs)
    }

    public static func convertAttribute(_ attr: LookinAttribute) -> LKAttribute {
        let value: LKAttributeValue
        if let strVal = attr.value as? String {
            value = .string(strVal)
        } else if let numVal = attr.value as? NSNumber {
            if attr.attrType == .BOOL {
                value = .bool(numVal.boolValue)
            } else {
                value = .number(numVal.doubleValue)
            }
        } else if attr.value == nil {
            value = .null
        } else {
            value = .string(String(describing: attr.value!))
        }

        return LKAttribute(
            key: attr.identifier ?? "",
            displayName: attr.displayTitle ?? attr.identifier ?? "",
            value: value,
            isReadonly: attr.customSetterID == nil && attr.attrType == .none
        )
    }

    // MARK: - Attribute extraction helpers

    private static func extractStringAttribute(_ key: String, from groups: [LookinAttributesGroup]?) -> String? {
        guard let groups else { return nil }
        for group in groups {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    if attr.identifier == key || attr.displayTitle == key {
                        return attr.value as? String
                    }
                }
            }
        }
        return nil
    }

    private static func extractIntAttribute(_ key: String, from groups: [LookinAttributesGroup]?) -> Int? {
        guard let groups else { return nil }
        for group in groups {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    if attr.identifier == key || attr.displayTitle == key {
                        return (attr.value as? NSNumber)?.intValue
                    }
                }
            }
        }
        return nil
    }

    private static func extractBoolAttribute(_ key: String, from groups: [LookinAttributesGroup]?) -> Bool? {
        guard let groups else { return nil }
        for group in groups {
            for section in group.attrSections ?? [] {
                for attr in section.attributes ?? [] {
                    if attr.identifier == key || attr.displayTitle == key {
                        return (attr.value as? NSNumber)?.boolValue
                    }
                }
            }
        }
        return nil
    }
}
