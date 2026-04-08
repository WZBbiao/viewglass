import Foundation
import LookinSharedBridge

/// Live mutation service that sends real modifications to iOS apps.
public final class LiveMutationService: MutationServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
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

        // Look up the node to get the correct viewOid/layerOid
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
        guard let node = snapshot.findNode(oid: nodeOid) else {
            throw LookinCoreError.nodeNotFound(oid: nodeOid)
        }

        let targetOid: UInt
        if mapping.targetIsLayer {
            targetOid = node.layerOid ?? node.oid
        } else {
            targetOid = node.viewOid ?? node.oid
        }

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

        // Look up the node to get the viewOid for method invocation
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
        let node = snapshot.findNode(oid: nodeOid)
        let targetOid = node?.viewOid ?? nodeOid

        let (description, _) = try await client.invokeMethod(oid: targetOid, selector: selector)

        return LKConsoleResult(
            expression: selector,
            targetOid: nodeOid,
            targetClass: node?.className ?? "UIView",
            returnValue: description,
            returnType: description == nil ? .void_ : .string,
            success: true
        )
    }
}
