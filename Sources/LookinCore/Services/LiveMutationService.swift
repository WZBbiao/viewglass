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

    struct CoordinateTapTarget {
        let metadata: TargetMetadata
        let frameToRoot: CGRect
        let point: CGPoint
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
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)

                guard let mapping = LKAttributeRegistry.mapping(for: key) else {
                    throw LookinCoreError.attributeModificationFailed(
                        key: key,
                        reason: "Unknown attribute key '\(key)'. Run 'viewglass attr keys' for the full list."
                    )
                }

                guard let parsedValue = LKAttributeRegistry.parseValue(value, attrType: mapping.attrType) else {
                    throw LookinCoreError.attributeModificationFailed(
                        key: key,
                        reason: "Cannot parse '\(value)' as \(mapping.attrType)"
                    )
                }

                let hierarchy = try await client.fetchHierarchy()

                let target = try resolveTargetMetadata(
                    nodeOid: nodeOid,
                    isLayerProperty: mapping.targetIsLayer,
                    hierarchy: hierarchy
                )
                if !mapping.requiredClasses.isEmpty {
                    try ensureClassChain(
                        target.classChain,
                        containsAny: mapping.requiredClasses,
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

                // For control-state properties (isOn, selectedSegmentIndex, etc.)
                // also send UIControlEventValueChanged so app callbacks fire.
                if mapping.sendsValueChanged {
                    let valueChangedMod = LookinAttributeModification()
                    valueChangedMod.targetOid = target.objectOid
                    valueChangedMod.setterSelector = NSSelectorFromString("sendActionsForControlEvents:")
                    valueChangedMod.getterSelector = NSSelectorFromString("allControlEvents")
                    valueChangedMod.attrType = .unsignedLong
                    valueChangedMod.value = NSNumber(value: 4096) // UIControlEventValueChanged
                    valueChangedMod.clientReadableVersion = LOOKIN_SERVER_READABLE_VERSION
                    try? await client.submitModification(valueChangedMod)
                }

                return LKModificationResult(
                    nodeOid: nodeOid,
                    attributeKey: key,
                    previousValue: "<live>",
                    newValue: value,
                    success: true
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.attributeModificationFailed(
            key: key,
            reason: "Unknown live mutation failure"
        )
    }

    /// Scroll a UIScrollView to `targetOffset` using UIKit's native `setContentOffset:animated:`.
    /// Blocks until the animation finishes (server defers TCP response by ~300 ms).
    public func scrollAnimated(
        nodeOid: UInt,
        targetOffset: CGPoint,
        sessionId: String
    ) async throws -> LKModificationResult {
        let client = try await sessionService.getClient(for: sessionId)
        _ = try await client.triggerSemanticScrollAnimated(
            oid: nodeOid,
            x: Double(targetOffset.x),
            y: Double(targetOffset.y)
        )
        return LKModificationResult(
            nodeOid: nodeOid,
            attributeKey: "contentOffset",
            previousValue: "",
            newValue: "\(targetOffset.x),\(targetOffset.y)",
            success: true
        )
    }

    public func triggerSwipe(
        nodeOid: UInt,
        direction: LKSwipeDirection,
        distance: CGFloat,
        animated: Bool,
        sessionId: String
    ) async throws -> LKActionResult {
        let client = try await sessionService.getClient(for: sessionId)
        let hierarchy = try await client.fetchHierarchy()
        let target = try resolveTargetMetadata(nodeOid: nodeOid, isLayerProperty: false, hierarchy: hierarchy)

        let scrollableClasses = ["UIScrollView", "UITableView", "UICollectionView", "UITextView", "WKWebView"]
        guard scrollableClasses.contains(where: { classChainMatches(target.classChain, requiredClass: $0, targetClass: target.className) }) else {
            throw LookinCoreError.actionFailed(
                action: "swipe",
                reason: "\(target.className)(oid:\(nodeOid)) is not a UIScrollView subclass. " +
                    "Swipe is only supported on UIScrollView and its subclasses. " +
                    "Use 'gesture' to inspect gesture recognizers on non-scrollable views."
            )
        }

        // Read current contentOffset
        let currentOffset: CGPoint
        if let (desc, _) = try? await client.invokeMethod(oid: target.objectOid, selector: "contentOffset"),
           let desc,
           let nsVal = LKAttributeRegistry.parseValue(desc, attrType: .cgPoint) as? NSValue {
            currentOffset = CGPoint(x: nsVal.pointValue.x, y: nsVal.pointValue.y)
        } else {
            currentOffset = .zero
        }

        let targetOffset: CGPoint
        switch direction {
        case .up:    targetOffset = CGPoint(x: currentOffset.x, y: currentOffset.y + distance)
        case .down:  targetOffset = CGPoint(x: currentOffset.x, y: max(0, currentOffset.y - distance))
        case .left:  targetOffset = CGPoint(x: currentOffset.x + distance, y: currentOffset.y)
        case .right: targetOffset = CGPoint(x: max(0, currentOffset.x - distance), y: currentOffset.y)
        }

        if animated {
            _ = try await scrollAnimated(nodeOid: nodeOid, targetOffset: targetOffset, sessionId: sessionId)
        } else {
            let value = "\(targetOffset.x),\(targetOffset.y)"
            _ = try await setAttribute(nodeOid: nodeOid, key: "contentOffset", value: value, sessionId: sessionId)
        }

        return LKActionResult(
            action: "swipe",
            nodeOid: nodeOid,
            targetClass: target.className,
            mode: .semantic,
            success: true,
            detail: "swiped \(direction.rawValue) by \(Int(distance))pt → contentOffset (\(Int(targetOffset.x)),\(Int(targetOffset.y)))\(animated ? " (animated)" : "")"
        )
    }

    public func invokeMethod(
        nodeOid: UInt,
        selector: String,
        args: [String],
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
            hasArg: !args.isEmpty,
            action: "invoke"
        )

        let (description, _) = try await client.invokeMethod(oid: target.objectOid, selector: selector, args: args)

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

        // UISwitch ignores TouchUpInside for toggling — it requires full touch tracking.
        // Instead, read the current isOn value and toggle it via setAttribute, which
        // also sends UIControlEventValueChanged so app-layer callbacks fire.
        if target.classChain.contains("UISwitch") || target.className == "UISwitch" {
            let (currentDescription, _) = try await client.invokeMethod(oid: target.objectOid, selector: "isOn")
            let currentIsOn = currentDescription.map { $0 == "1" || $0.lowercased() == "yes" || $0.lowercased() == "true" } ?? false
            let newIsOn = !currentIsOn
            _ = try await setAttribute(nodeOid: nodeOid, key: "isOn", value: newIsOn ? "true" : "false", sessionId: sessionId)
            return LKActionResult(
                action: "control-tap",
                nodeOid: nodeOid,
                targetClass: target.className,
                mode: .semantic,
                success: true,
                detail: "Toggled UISwitch isOn: \(currentIsOn) → \(newIsOn)"
            )
        }

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

                do {
                    let detail = try await client.triggerSemanticTap(oid: target.objectOid)

                    return LKActionResult(
                        action: "tap",
                        nodeOid: nodeOid,
                        targetClass: target.className,
                        mode: .semantic,
                        success: true,
                        detail: detail ?? "Triggered semantic tap",
                        strategyUsed: "semantic"
                    )
                } catch {
                    guard let fallbackReason = coordinateSemanticFallbackReason(for: error) else {
                        throw error
                    }

                    let coordinateTarget = try resolveCoordinateTapTarget(
                        nodeOid: target.nodeOid,
                        isLayerProperty: false,
                        hierarchy: hierarchy
                    )
                    let response = try await client.triggerCoordinateSemanticTap(
                        x: Double(coordinateTarget.point.x),
                        y: Double(coordinateTarget.point.y),
                        sourceOid: target.objectOid
                    )
                    let pointDescription = formatPoint(coordinateTarget.point)
                    let detail = "Fallback coordinateSemantic tap at \(pointDescription): \(response.detail ?? "Triggered coordinate semantic tap")"

                    return LKActionResult(
                        action: "tap",
                        nodeOid: nodeOid,
                        targetClass: response.hitClass ?? target.className,
                        mode: .semantic,
                        success: true,
                        detail: detail,
                        strategyUsed: response.strategy ?? "coordinateSemantic",
                        fallbackReason: fallbackReason,
                        pointX: Double(coordinateTarget.point.x),
                        pointY: Double(coordinateTarget.point.y),
                        hitOid: response.hitOid,
                        hitClass: response.hitClass
                    )
                }
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
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
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.actionFailed(action: "long-press", reason: "Unknown semantic long press failure")
    }

    public func triggerDismiss(
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
                try ensureClassChain(
                    target.classChain,
                    contains: "UIViewController",
                    action: "dismiss",
                    targetClass: target.className
                )

                let detail = try await client.triggerSemanticDismiss(oid: target.objectOid)
                return LKActionResult(
                    action: "dismiss",
                    nodeOid: nodeOid,
                    targetClass: target.className,
                    mode: .semantic,
                    success: true,
                    detail: detail ?? "Dismissed \(target.className)"
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.actionFailed(action: "dismiss", reason: "Unknown dismiss failure")
    }

    public func inputText(
        nodeOid: UInt,
        text: String,
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
                do {
                    try ensureClassChain(
                        target.classChain,
                        containsAny: ["UITextField", "UITextView"],
                        action: "input",
                        targetClass: target.className
                    )
                } catch {
                    throw LookinCoreError.actionFailed(
                        action: "input",
                        reason: "\(target.className) is not a supported text input target. Use UITextField or UITextView."
                    )
                }

                let detail = try await client.triggerSemanticTextInput(oid: target.objectOid, text: text)
                return LKActionResult(
                    action: "input",
                    nodeOid: nodeOid,
                    targetClass: target.className,
                    mode: .semantic,
                    success: true,
                    detail: detail ?? "Inserted \(text.count) characters"
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.actionFailed(action: "input", reason: "Unknown semantic text input failure")
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
              let target = findTarget(oid: nodeOid, isLayerProperty: isLayerProperty, in: items) else {
            throw LookinCoreError.nodeNotFound(oid: nodeOid)
        }
        return TargetMetadata(
            nodeOid: nodeOid,
            objectOid: target.objectOid,
            className: target.className,
            classChain: target.classChain
        )
    }

    func resolveCoordinateTapTarget(
        nodeOid: UInt,
        isLayerProperty: Bool,
        hierarchy: LookinHierarchyInfo
    ) throws -> CoordinateTapTarget {
        guard let items = hierarchy.displayItems,
              let target = findCoordinateTapTarget(oid: nodeOid, isLayerProperty: isLayerProperty, in: items) else {
            throw LookinCoreError.nodeNotFound(oid: nodeOid)
        }

        guard target.frameToRoot.width > 0, target.frameToRoot.height > 0 else {
            throw LookinCoreError.actionFailed(
                action: "tap",
                reason: "\(target.metadata.className)(oid:\(nodeOid)) has an invalid frame for coordinate fallback"
            )
        }

        let screenWidth = hierarchy.appInfo?.screenWidth ?? 0
        let screenHeight = hierarchy.appInfo?.screenHeight ?? 0
        let tappableFrame: CGRect
        if screenWidth > 0, screenHeight > 0 {
            let screenRect = CGRect(x: 0, y: 0, width: CGFloat(screenWidth), height: CGFloat(screenHeight))
            tappableFrame = target.frameToRoot.intersection(screenRect)
        } else {
            tappableFrame = target.frameToRoot
        }

        guard !tappableFrame.isNull, !tappableFrame.isEmpty, tappableFrame.width > 0, tappableFrame.height > 0 else {
            throw LookinCoreError.actionFailed(
                action: "tap",
                reason: "\(target.metadata.className)(oid:\(nodeOid)) is outside the visible screen for coordinate fallback"
            )
        }

        let point = CGPoint(x: tappableFrame.midX, y: tappableFrame.midY)
        return CoordinateTapTarget(metadata: target.metadata, frameToRoot: target.frameToRoot, point: point)
    }

    func ensureClassChain(
        _ classChain: [String],
        contains requiredClass: String,
        action: String,
        targetClass: String
    ) throws {
        try ensureClassChain(
            classChain,
            containsAny: [requiredClass],
            action: action,
            targetClass: targetClass
        )
    }

    func ensureClassChain(
        _ classChain: [String],
        containsAny requiredClasses: [String],
        action: String,
        targetClass: String
    ) throws {
        guard requiredClasses.contains(where: { classChainMatches(classChain, requiredClass: $0, targetClass: targetClass) }) else {
            let requirement = requiredClasses.count == 1
                ? requiredClasses[0]
                : requiredClasses.joined(separator: ", ")
            throw LookinCoreError.actionFailed(
                action: action,
                reason: "\(targetClass) is not a \(requirement) subclass"
            )
        }
    }

    private func classChainMatches(_ classChain: [String], requiredClass: String, targetClass: String) -> Bool {
        let names = Set(classChain + [targetClass])
        if names.contains(requiredClass) {
            return true
        }

        switch requiredClass {
        case "UIScrollView":
            return names.contains { isScrollViewClassName($0) }
        case "UITableView":
            return names.contains { $0 == "UITableView" || $0.hasSuffix("TableView") }
        case "UICollectionView":
            return names.contains { $0 == "UICollectionView" || $0.hasSuffix("CollectionView") }
        case "UITextField":
            return names.contains { $0.localizedCaseInsensitiveContains("TextField") }
        case "UITextView":
            return names.contains { $0.localizedCaseInsensitiveContains("TextView") }
        case "UILabel":
            return names.contains { $0.localizedCaseInsensitiveContains("Label") }
        case "UIControl":
            return names.contains { $0.localizedCaseInsensitiveContains("Control") }
        default:
            return false
        }
    }

    private func isScrollViewClassName(_ className: String) -> Bool {
        className == "UIScrollView" ||
            className == "UITableView" ||
            className == "UICollectionView" ||
            className == "UITextView" ||
            className == "WKWebView" ||
            className.localizedCaseInsensitiveContains("ScrollView") ||
            className.hasSuffix("TableView") ||
            className.hasSuffix("CollectionView")
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
        switch error {
        case let LookinCoreError.protocolError(reason):
            let normalized = reason.localizedCaseInsensitiveContains("connection closed")
                || reason.localizedCaseInsensitiveContains("connect failed")
                || reason.localizedCaseInsensitiveContains("operation not permitted")
            return normalized
        case let LookinCoreError.appNotFound(identifier):
            return !identifier.isEmpty
        default:
            return false
        }
    }

    private func coordinateSemanticFallbackReason(for error: Error) -> String? {
        guard case let LookinCoreError.protocolError(reason) = error else {
            return nil
        }
        if reason.localizedCaseInsensitiveContains("didn't find a tappable") ||
            reason.localizedCaseInsensitiveContains("did not find a tappable") {
            return reason
        }
        return nil
    }

    private func formatPoint(_ point: CGPoint) -> String {
        "{\(formatNumber(Double(point.x))),\(formatNumber(Double(point.y)))}"
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func frameToRoot(
        for item: LookinDisplayItem,
        parentFrameToRoot: CGRect?,
        parentBounds: CGRect?
    ) -> CGRect {
        guard let parentFrameToRoot, let parentBounds else {
            return item.frame
        }
        return CGRect(
            x: item.frame.origin.x - parentBounds.origin.x + parentFrameToRoot.origin.x,
            y: item.frame.origin.y - parentBounds.origin.y + parentFrameToRoot.origin.y,
            width: item.frame.size.width,
            height: item.frame.size.height
        )
    }

    private func findCoordinateTapTarget(
        oid: UInt,
        isLayerProperty: Bool,
        in items: [LookinDisplayItem],
        parentFrameToRoot: CGRect? = nil,
        parentBounds: CGRect? = nil
    ) -> (metadata: TargetMetadata, frameToRoot: CGRect)? {
        for item in items {
            let currentFrameToRoot = frameToRoot(for: item, parentFrameToRoot: parentFrameToRoot, parentBounds: parentBounds)
            let layerMatches = UInt(item.layerObject?.oid ?? 0) == oid
            let viewMatches = UInt(item.viewObject?.oid ?? 0) == oid

            if isLayerProperty,
               let layer = item.layerObject,
               layerMatches {
                let className = layer.rawClassName() ?? "CALayer"
                let metadata = TargetMetadata(
                    nodeOid: oid,
                    objectOid: UInt(layer.oid),
                    className: className,
                    classChain: layer.classChainList ?? [className]
                )
                return (metadata, currentFrameToRoot)
            }

            if let view = item.viewObject, viewMatches || (!isLayerProperty && layerMatches) {
                let className = view.rawClassName() ?? "UIView"
                let metadata = TargetMetadata(
                    nodeOid: oid,
                    objectOid: UInt(view.oid),
                    className: className,
                    classChain: view.classChainList ?? [className]
                )
                return (metadata, currentFrameToRoot)
            }

            if let found = findCoordinateTapTarget(
                oid: oid,
                isLayerProperty: isLayerProperty,
                in: item.subitems ?? [],
                parentFrameToRoot: currentFrameToRoot,
                parentBounds: item.bounds
            ) {
                return found
            }
        }
        return nil
    }

    private func findTarget(
        oid: UInt,
        isLayerProperty: Bool,
        in items: [LookinDisplayItem]
    ) -> (objectOid: UInt, className: String, classChain: [String])? {
        for item in items {
            let layerMatches = UInt(item.layerObject?.oid ?? 0) == oid
            let viewMatches = UInt(item.viewObject?.oid ?? 0) == oid

            if !isLayerProperty,
               let controller = item.hostViewControllerObject,
               UInt(controller.oid) == oid {
                let className = controller.rawClassName() ?? "UIViewController"
                return (
                    objectOid: UInt(controller.oid),
                    className: className,
                    classChain: controller.classChainList ?? [className]
                )
            }

            if isLayerProperty,
               let layer = item.layerObject,
               layerMatches {
                let className = layer.rawClassName() ?? "CALayer"
                return (
                    objectOid: UInt(layer.oid),
                    className: className,
                    classChain: layer.classChainList ?? [className]
                )
            }

            if let view = item.viewObject, viewMatches {
                let className = view.rawClassName() ?? "UIView"
                return (
                    objectOid: UInt(view.oid),
                    className: className,
                    classChain: view.classChainList ?? [className]
                )
            }

            if !isLayerProperty,
               layerMatches,
               let view = item.viewObject {
                let className = view.rawClassName() ?? "UIView"
                return (
                    objectOid: UInt(view.oid),
                    className: className,
                    classChain: view.classChainList ?? [className]
                )
            }

            if let found = findTarget(oid: oid, isLayerProperty: isLayerProperty, in: item.subitems ?? []) {
                return found
            }
        }
        return nil
    }
}
