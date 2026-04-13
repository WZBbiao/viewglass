import Foundation
import LookinSharedBridge

/// Live mutation service that sends real modifications to iOS apps.
/// Ensures hierarchy is fetched first to register OID mappings with the server.
public final class LiveMutationService: MutationServiceProtocol, @unchecked Sendable {
    struct TargetMetadata {
        let nodeOid: UInt
        let objectOid: UInt
        let className: String
        let classChain: [String]
    }

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

        let target = try resolveTargetMetadata(
            nodeOid: nodeOid,
            isLayerProperty: mapping.targetIsLayer,
            hierarchy: hierarchy
        )
        if let requiredClass = mapping.requiredClass {
            try ensureClassChain(
                target.classChain,
                contains: requiredClass,
                action: "set-attribute:\(key)",
                targetClass: target.className
            )
        }
        try await ensureSelectorExists(
            client: client,
            className: target.className,
            selector: mapping.setter,
            hasArg: true,
            action: "set-attribute:\(key)"
        )
        try await ensureSelectorExists(
            client: client,
            className: target.className,
            selector: mapping.getter,
            hasArg: false,
            action: "set-attribute:\(key)"
        )

        let modification = LookinAttributeModification()
        modification.targetOid = target.objectOid
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

        let target = try resolveTargetMetadata(
            nodeOid: nodeOid,
            isLayerProperty: false,
            hierarchy: hierarchy
        )
        try await ensureSelectorExists(
            client: client,
            className: target.className,
            selector: selector,
            hasArg: false,
            action: "invoke"
        )

        let (description, _) = try await client.invokeMethod(oid: target.objectOid, selector: selector)

        return LKConsoleResult(
            expression: selector,
            targetOid: nodeOid,
            targetClass: target.className,
            returnValue: description,
            returnType: description == nil ? .void_ : .string,
            success: true
        )
    }

    public func triggerControlTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        let client = try await sessionService.getClient(for: sessionId)
        let hierarchy = try await client.fetchHierarchy()
        let target = try resolveTargetMetadata(
            nodeOid: nodeOid,
            isLayerProperty: false,
            hierarchy: hierarchy
        )
        try ensureClassChain(
            target.classChain,
            contains: "UIControl",
            action: "control-tap",
            targetClass: target.className
        )
        try await ensureSelectorExists(
            client: client,
            className: target.className,
            selector: "sendActionsForControlEvents:",
            hasArg: true,
            action: "control-tap"
        )
        try await ensureSelectorExists(
            client: client,
            className: target.className,
            selector: "allControlEvents",
            hasArg: false,
            action: "control-tap"
        )

        let modification = LookinAttributeModification()
        modification.targetOid = target.objectOid
        modification.setterSelector = NSSelectorFromString("sendActionsForControlEvents:")
        modification.getterSelector = NSSelectorFromString("allControlEvents")
        modification.attrType = .unsignedLong
        modification.value = NSNumber(value: 64) // UIControlEventTouchUpInside
        modification.clientReadableVersion = LOOKIN_SERVER_READABLE_VERSION

        try await client.submitModification(modification)

        return LKActionResult(
            action: "control-tap",
            nodeOid: nodeOid,
            targetClass: target.className,
            mode: .semantic,
            success: true,
            detail: "Triggered UIControlEventTouchUpInside"
        )
    }

    public func triggerTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)
                let hierarchy = try await client.fetchHierarchy()
                let target = try resolveTargetMetadata(
                    nodeOid: nodeOid,
                    isLayerProperty: false,
                    hierarchy: hierarchy
                )

                let detail = try await client.triggerSemanticTap(oid: target.objectOid)

                return LKActionResult(
                    action: "tap",
                    nodeOid: nodeOid,
                    targetClass: target.className,
                    mode: .semantic,
                    success: true,
                    detail: detail ?? "Triggered semantic tap"
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
            }
        }

        throw lastError ?? LookinCoreError.actionFailed(action: "tap", reason: "Unknown semantic tap failure")
    }

    public func triggerLongPress(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)
                let hierarchy = try await client.fetchHierarchy()
                let target = try resolveTargetMetadata(
                    nodeOid: nodeOid,
                    isLayerProperty: false,
                    hierarchy: hierarchy
                )

                let detail = try await client.triggerSemanticLongPress(oid: target.objectOid)

                return LKActionResult(
                    action: "long-press",
                    nodeOid: nodeOid,
                    targetClass: target.className,
                    mode: .semantic,
                    success: true,
                    detail: detail ?? "Triggered semantic long press"
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
            }
        }

        throw lastError ?? LookinCoreError.actionFailed(action: "long-press", reason: "Unknown semantic long press failure")
    }

    public func inspectGestures(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKGestureInspectionResult {
        let client = try await sessionService.getClient(for: sessionId)
        let hierarchy = try await client.fetchHierarchy()
        let target = try resolveTargetMetadata(
            nodeOid: nodeOid,
            isLayerProperty: false,
            hierarchy: hierarchy
        )
        let result = try await client.invokeMethod(oid: target.objectOid, selector: "gestureRecognizers")
        let rawValue = result.0 ?? ""
        let gestures = LKGestureRecognizerParser.parse(rawValue)
        return LKGestureInspectionResult(
            nodeOid: nodeOid,
            targetClass: target.className,
            gestures: gestures,
            rawValue: rawValue
        )
    }

    func resolveTargetMetadata(
        nodeOid: UInt,
        isLayerProperty: Bool,
        hierarchy: LookinHierarchyInfo
    ) throws -> TargetMetadata {
        guard let items = hierarchy.displayItems,
              let item = findItem(oid: nodeOid, in: items) else {
            throw LookinCoreError.nodeNotFound(oid: nodeOid)
        }

        let object = isLayerProperty ? (item.layerObject ?? item.viewObject) : (item.viewObject ?? item.layerObject)
        guard let object else {
            throw LookinCoreError.actionFailed(
                action: "resolve-target",
                reason: "Unable to locate runtime object for node \(nodeOid)"
            )
        }

        let className = object.rawClassName() ?? "NSObject"
        return TargetMetadata(
            nodeOid: nodeOid,
            objectOid: UInt(object.oid),
            className: className,
            classChain: object.classChainList ?? [className]
        )
    }

    func ensureClassChain(
        _ classChain: [String],
        contains requiredClass: String,
        action: String,
        targetClass: String
    ) throws {
        guard classChain.contains(requiredClass) || targetClass == requiredClass else {
            throw LookinCoreError.actionFailed(
                action: action,
                reason: "\(targetClass) is not a \(requiredClass) subclass"
            )
        }
    }

    private func ensureSelectorExists(
        client: LKProtocolClient,
        className: String,
        selector: String,
        hasArg: Bool,
        action: String
    ) async throws {
        let selectorNames = try await client.fetchSelectorNames(className: className, hasArg: hasArg)
        guard selectorNames.contains(selector) else {
            throw LookinCoreError.actionFailed(
                action: action,
                reason: "\(className) does not respond to \(selector)"
            )
        }
    }

    private func shouldRetry(after error: Error) -> Bool {
        guard case let LookinCoreError.protocolError(reason) = error else {
            return false
        }
        return reason.localizedCaseInsensitiveContains("connection closed")
    }

    private func findItem(oid: UInt, in items: [LookinDisplayItem]) -> LookinDisplayItem? {
        for item in items {
            if UInt(item.layerObject?.oid ?? 0) == oid || UInt(item.viewObject?.oid ?? 0) == oid {
                return item
            }
            if let found = findItem(oid: oid, in: item.subitems ?? []) {
                return found
            }
        }
        return nil
    }
}
