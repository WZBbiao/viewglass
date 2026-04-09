import Foundation

public final class LKTargetResolver: Sendable {
    private let queryEngine = LKQueryEngine()

    public init() {}

    public func resolve(locator: LKLocator, in snapshot: LKHierarchySnapshot) throws -> LKResolvedTarget {
        let nodes = try matchedNodes(for: locator, in: snapshot)
        let matches = nodes.map { node in
            LKResolvedMatch(node: node, capabilities: capabilities(for: node))
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
            return snapshot.flatNodes.filter { $0.hostViewControllerClassName == locator.value }
        case .query:
            return try queryEngine.execute(expression: locator.value, on: snapshot)
        }
    }

    private func capabilities(for node: LKNode) -> [String: LKCapability] {
        let classChain = [node.className, node.hostViewControllerClassName].compactMap { $0 }
        let isController = classChain.contains { $0.contains("Controller") } || node.hostViewControllerOid == node.primaryOid
        let isScrollView = classChain.contains("UIScrollView")
        let isActionableView = node.isUserInteractionEnabled || node.className == "UIControl" || node.hostViewControllerOid != nil

        return [
            "inspect": LKCapability(supported: true),
            "capture": LKCapability(supported: true),
            "tap": isActionableView
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not user-interactable"),
            "scroll": isScrollView
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not a UIScrollView subclass"),
            "dismiss": isController || node.hostViewControllerOid != nil
                ? LKCapability(supported: true)
                : LKCapability(supported: false, reason: "target is not a UIViewController subclass"),
            "invoke": LKCapability(supported: true)
        ]
    }
}
