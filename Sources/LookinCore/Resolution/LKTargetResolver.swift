import Foundation

public final class LKTargetResolver: Sendable {
    private let queryEngine = LKQueryEngine()

    public init() {}

    public func resolve(locator: LKLocator, in snapshot: LKHierarchySnapshot) throws -> LKResolvedTarget {
        let nodes = try matchedNodes(for: locator, in: snapshot)
        let matches = nodes.map { node in
            LKResolvedMatch(
                node: node,
                targets: targets(for: node),
                capabilities: capabilities(for: node)
            )
        }
        let selectedTarget = matches.count == 1 ? matches[0] : nil
        return LKResolvedTarget(
            locator: locator,
            snapshotId: snapshot.snapshotId,
            fetchedAt: snapshot.fetchedAt,
            matches: matches,
            selectedTarget: selectedTarget
        )
    }

    private func matchedNodes(for locator: LKLocator, in snapshot: LKHierarchySnapshot) throws -> [LKNode] {
        switch locator.kind {
        case .oid:
            guard let oid = UInt(locator.value) else {
                throw LookinCoreError.querySyntaxError(expression: locator.rawValue, reason: "Invalid oid value")
            }
            return snapshot.flatNodes.filter { $0.oid == oid || $0.viewOid == oid || $0.layerOid == oid || $0.hostViewControllerOid == oid }
        case .primaryOid:
            guard let oid = UInt(locator.value) else {
                throw LookinCoreError.querySyntaxError(expression: locator.rawValue, reason: "Invalid primaryOid value")
            }
            return snapshot.flatNodes.filter { $0.primaryOid == oid || $0.hostViewControllerOid == oid }
        case .accessibilityIdentifier:
            return snapshot.flatNodes.filter { $0.accessibilityIdentifier == locator.value }
        case .accessibilityLabel:
            return snapshot.flatNodes.filter { $0.accessibilityLabel == locator.value }
        case .controller:
            return snapshot.flatNodes.filter {
                guard let className = $0.hostViewControllerClassName else { return false }
                return matchesClass(className, query: locator.value)
            }
        case .query:
            return try queryEngine.execute(expression: locator.value, on: snapshot)
        }
    }

    private func targets(for node: LKNode) -> LKResolvedObjectTargets {
        let inspectOid = node.layerOid ?? node.viewOid ?? node.primaryOid
        let actionOid = node.viewOid ?? node.hostViewControllerOid ?? node.primaryOid
        let captureOid = node.layerOid ?? node.viewOid ?? node.primaryOid
        let controllerOid = node.hostViewControllerOid
        let viewOid = node.viewOid ?? node.primaryOid
        let scrollOid = isScrollViewLike(node) ? viewOid : nil
        let textInputOid = isTextInputLike(node) ? viewOid : nil

        return LKResolvedObjectTargets(
            inspectOid: inspectOid,
            actionOid: actionOid,
            captureOid: captureOid,
            controllerOid: controllerOid,
            scrollOid: scrollOid,
            textInputOid: textInputOid
        )
    }

    private func capabilities(for node: LKNode) -> [String: LKCapability] {
        let isControllerTarget = node.hostViewControllerOid == node.primaryOid ||
            node.className == "UIViewController" ||
            node.className.hasSuffix("ViewController")
        let isScrollView = isScrollViewLike(node)
        let isActionableView = node.isUserInteractionEnabled || node.className == "UIControl" || node.hostViewControllerOid != nil
        let isTextInput = isTextInputLike(node)

        return [
            "inspect": LKCapability(supported: true),
            "capture": LKCapability(supported: true),
            "tap": isActionableView
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not user-interactable"),
            "scroll": isScrollView
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not a UIScrollView subclass"),
            "dismiss": isControllerTarget || node.hostViewControllerOid != nil
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not a UIViewController subclass"),
            "input": isTextInput
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not a UITextField, UITextView, or WKWebView editor"),
            "invoke": LKCapability(supported: true)
        ]
    }

    private func isScrollViewLike(_ node: LKNode) -> Bool {
        classNames(for: node).contains { className in
            className == "UIScrollView" ||
                className == "UITableView" ||
                className == "UICollectionView" ||
                className == "UITextView" ||
                className == "WKWebView" ||
                className.localizedCaseInsensitiveContains("ScrollView") ||
                className.hasSuffix("TableView") ||
                className.hasSuffix("CollectionView")
        }
    }

    private func isTextInputLike(_ node: LKNode) -> Bool {
        classNames(for: node).contains { className in
                className == "UITextField" ||
                className == "UITextView" ||
                className == "WKWebView" ||
                className == "WKContentView" ||
                className.localizedCaseInsensitiveContains("TextField") ||
                className.localizedCaseInsensitiveContains("TextView") ||
                className.localizedCaseInsensitiveContains("WKWebView") ||
                className.localizedCaseInsensitiveContains("WKContentView")
        }
    }

    private func classNames(for node: LKNode) -> [String] {
        [node.className, node.hostViewControllerClassName].compactMap { $0 }
    }

    private func matchesClass(_ candidate: String, query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return false }

        if candidate.localizedCaseInsensitiveContains(trimmedQuery) {
            return true
        }

        if let simpleName = candidate.split(separator: ".").last {
            return String(simpleName).localizedCaseInsensitiveContains(trimmedQuery)
        }

        return false
    }
}
