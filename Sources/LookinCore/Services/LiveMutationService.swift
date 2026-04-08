import Foundation
import LookinSharedBridge

/// Live mutation service that sends real modifications to iOS apps.
/// Ensures hierarchy is fetched first to register OID mappings with the server.
public final class LiveMutationService: MutationServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService

    public init(sessionService: LiveSessionService) {
        self.sessionService = sessionService
    }

    public func setAttribute(
        nodeOid: UInt,
        key: String,
        value: String,
        sessionId: String
    ) async throws -> LKModificationResult {
        let client = try await sessionService.getClient(for: sessionId)

        guard let mapping = LKAttributeRegistry.mapping(for: key) else {
            throw LookinCoreError.attributeModificationFailed(
                key: key,
                reason: "Unknown attribute '\(key)'. Available: \(LKAttributeRegistry.allKeys.joined(separator: ", "))"
            )
        }

        guard let parsedValue = LKAttributeRegistry.parseValue(value, attrType: mapping.attrType) else {
            throw LookinCoreError.attributeModificationFailed(
                key: key,
                reason: "Cannot parse '\(value)' as \(mapping.attrType)"
            )
        }

        // Fetch hierarchy to register OID mappings with the server.
        let hierarchy = try await client.fetchHierarchy()

        // Find the target OID from the hierarchy
        let targetOid = findTargetOid(
            nodeOid: nodeOid,
            isLayerProperty: mapping.targetIsLayer,
            hierarchy: hierarchy
        )

        let modification = LookinAttributeModification()
        modification.targetOid = targetOid
        modification.setterSelector = NSSelectorFromString(mapping.setter)
        modification.getterSelector = NSSelectorFromString(mapping.getter)
        modification.attrType = mapping.attrType
        modification.value = parsedValue
        modification.clientReadableVersion = LOOKIN_SERVER_READABLE_VERSION

        try await client.submitModification(modification)

        return LKModificationResult(
            nodeOid: nodeOid,
            attributeKey: key,
            previousValue: "<live>",
            newValue: value,
            success: true
        )
    }

    public func invokeMethod(
        nodeOid: UInt,
        selector: String,
        sessionId: String
    ) async throws -> LKConsoleResult {
        let client = try await sessionService.getClient(for: sessionId)

        // Fetch hierarchy to register OID mappings
        let hierarchy = try await client.fetchHierarchy()

        // Find viewOid for method invocation
        let targetOid = findViewOid(nodeOid: nodeOid, hierarchy: hierarchy)

        let (description, _) = try await client.invokeMethod(oid: targetOid, selector: selector)

        return LKConsoleResult(
            expression: selector,
            targetOid: nodeOid,
            targetClass: "UIView",
            returnValue: description,
            returnType: description == nil ? .void_ : .string,
            success: true
        )
    }

    /// Find the correct target OID from the hierarchy.
    /// The hierarchy reports nodes by layer OID. For view properties, we need the view OID.
    private func findTargetOid(nodeOid: UInt, isLayerProperty: Bool, hierarchy: LookinHierarchyInfo) -> UInt {
        guard let items = hierarchy.displayItems else { return nodeOid }
        if let item = findItem(oid: nodeOid, in: items) {
            if isLayerProperty {
                return item.layerObject?.oid ?? nodeOid
            } else {
                return item.viewObject?.oid ?? nodeOid
            }
        }
        return nodeOid
    }

    private func findViewOid(nodeOid: UInt, hierarchy: LookinHierarchyInfo) -> UInt {
        guard let items = hierarchy.displayItems else { return nodeOid }
        if let item = findItem(oid: nodeOid, in: items) {
            return item.viewObject?.oid ?? nodeOid
        }
        return nodeOid
    }

    private func findItem(oid: UInt, in items: [LookinDisplayItem]) -> LookinDisplayItem? {
        for item in items {
            let itemOid = item.layerObject?.oid ?? item.viewObject?.oid ?? 0
            if itemOid == oid { return item }
            if let found = findItem(oid: oid, in: item.subitems ?? []) {
                return found
            }
        }
        return nil
    }
}
