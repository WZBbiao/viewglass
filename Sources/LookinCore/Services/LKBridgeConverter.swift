import Foundation
import LookinSharedBridge

/// Converts LookinSharedBridge ObjC types to LookinCore Swift DTOs.
public enum LKBridgeConverter {

    public static func convertAppInfo(
        _ info: LookinAppInfo,
        host: String = "127.0.0.1",
        port: Int,
        remotePort: Int? = nil,
        deviceType: LKAppDescriptor.DeviceType,
        deviceIdentifier: String? = nil
    ) -> LKAppDescriptor {
        LKAppDescriptor(
            appName: info.appName ?? "Unknown",
            bundleIdentifier: info.appBundleIdentifier ?? "unknown",
            appVersion: nil,
            deviceName: info.deviceDescription,
            deviceType: deviceType,
            host: host,
            port: port,
            remotePort: remotePort,
            deviceIdentifier: deviceIdentifier,
            serverVersion: info.serverReadableVersion
        )
    }

    public static func convertHierarchy(_ info: LookinHierarchyInfo, app: LKAppDescriptor) -> LKHierarchySnapshot {
        let windows = convertDisplayItemTrees(info.displayItems ?? [], depth: 0, parentOid: nil)

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
        let primaryOid = item.viewObject?.oid ?? item.layerObject?.oid ?? 0
        let children = convertDisplayItemTrees(item.subitems ?? [], depth: depth + 1, parentOid: UInt(primaryOid))
        let node = convertDisplayItem(
            item,
            depth: depth,
            parentOid: parentOid,
            childrenOids: children.map(\.node.oid)
        )
        return LKNodeTree(node: node, children: children)
    }

    public static func convertDisplayItem(
        _ item: LookinDisplayItem,
        depth: Int,
        parentOid: UInt?,
        childrenOids: [UInt]? = nil
    ) -> LKNode {
        let viewOid = item.viewObject?.oid
        let layerOid = item.layerObject?.oid
        // Use viewOid as the primary node identifier so that hierarchy display
        // and action targets (tap/input/attr set) reference the same OID.
        let oid = viewOid ?? layerOid ?? 0
        let primaryOid = viewOid ?? layerOid ?? 0
        let oidType: LKNodeOIDType = {
            if viewOid != nil { return .view }
            if layerOid != nil { return .layer }
            return .unknown
        }()
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

        let resolvedChildrenOids = childrenOids ?? (item.subitems ?? []).compactMap { child -> UInt? in
            guard let oid = child.viewObject?.oid ?? child.layerObject?.oid else { return nil }
            return UInt(oid)
        }

        let attrGroups = item.attributesGroupList?.map { convertAttributesGroup($0) }

        // Extract tag, accessibility, and interaction info from attribute groups
        let tag = extractIntAttribute("tag", from: item.attributesGroupList)
        let accessibilityLabel = extractStringAttribute("accessibilityLabel", from: item.attributesGroupList)
        let accessibilityIdentifier = extractStringAttribute("accessibilityIdentifier", from: item.attributesGroupList)
        let isUserInteractionEnabled = extractBoolAttribute("userInteractionEnabled", from: item.attributesGroupList) ?? true
        let hostViewControllerClassName = item.hostViewControllerObject?.rawClassName()
        let hostViewControllerOid = item.hostViewControllerObject?.oid

        return LKNode(
            oid: UInt(oid),
            primaryOid: UInt(primaryOid),
            oidType: oidType,
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
            hostViewControllerClassName: hostViewControllerClassName,
            hostViewControllerOid: hostViewControllerOid.map { UInt($0) },
            customDisplayTitle: item.customDisplayTitle,
            depth: depth,
            parentOid: parentOid,
            childrenOids: resolvedChildrenOids,
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

    // MARK: - System hierarchy noise filtering

    private enum SystemNoisePolicy {
        case elideNode
        case dropSubtree
    }

    private static func convertDisplayItemTrees(
        _ items: [LookinDisplayItem],
        depth: Int,
        parentOid: UInt?
    ) -> [LKNodeTree] {
        items.flatMap { item -> [LKNodeTree] in
            switch systemNoisePolicy(for: item) {
            case .elideNode:
                return convertDisplayItemTrees(item.subitems ?? [], depth: depth, parentOid: parentOid)
            case .dropSubtree:
                return []
            case .none:
                return [convertDisplayItemTree(item, depth: depth, parentOid: parentOid)]
            }
        }
    }

    private static func systemNoisePolicy(for item: LookinDisplayItem) -> SystemNoisePolicy? {
        let className = item.viewObject?.rawClassName() ?? item.layerObject?.rawClassName() ?? ""
        switch className {
        case "_UITouchPassthroughView",
             "_UIMultiLayer",
             "_UITabBarContainerWrapperView",
             "UIKit._UITabBarContainerWrapperView",
             "_UITabBarContainerView",
             "UIKit._UITabBarContainerView":
            return .elideNode
        case "_UIFloatingBarContainerView",
             "_UIPointerInteractionAssistantEffectContainerView",
             "_UIPortalView":
            return .dropSubtree
        default:
            break
        }

        if className.contains("FloatingBarHostingView") && className.contains("FloatingBarContainer") {
            return .dropSubtree
        }
        if className.contains("ScrollEdgeEffectView") {
            return .dropSubtree
        }
        return nil
    }
}
