import ArgumentParser
import CoreGraphics
import LookinCore

struct ScrollInsets: Equatable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    static let zero = ScrollInsets(top: 0, left: 0, bottom: 0, right: 0)
}

struct ScrollTargetResolution: Equatable {
    var requestedOffset: CGPoint
    var targetOffset: CGPoint

    var didClamp: Bool {
        abs(requestedOffset.x - targetOffset.x) >= 0.5 ||
            abs(requestedOffset.y - targetOffset.y) >= 0.5
    }
}

struct ScrollMetrics: Equatable {
    var contentOffset: CGPoint
    var contentSize: CGSize?
    var viewportSize: CGSize?
    var adjustedContentInset: ScrollInsets

    func clampedOffset(_ requested: CGPoint) -> CGPoint {
        guard let contentSize, let viewportSize else {
            return requested
        }

        let minX = -adjustedContentInset.left
        let minY = -adjustedContentInset.top
        let maxX = max(minX, contentSize.width - viewportSize.width + adjustedContentInset.right)
        let maxY = max(minY, contentSize.height - viewportSize.height + adjustedContentInset.bottom)

        return CGPoint(
            x: min(max(requested.x, minX), maxX),
            y: min(max(requested.y, minY), maxY)
        )
    }
}

struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll a UIScrollView node using semantic actions"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, help: "Scroll to absolute content offset as 'x,y'")
    var to: String?

    @Option(name: .long, help: "Scroll by delta offset as 'dx,dy'")
    var by: String?

    @Option(name: .long, help: "Execution mode: auto, semantic, or physical")
    var mode: CLIActionExecutionMode = .auto

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Animate the scroll using UIKit's native setContentOffset:animated: (smooth, on-device timing curve)")
    var animated = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }

        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                target,
                services: services,
                sessionId: sessionId,
                action: "scroll",
                capability: "scroll"
            )
            let baseNode = resolved.node
            let scrollOid = resolved.targets.scrollOid ?? resolved.targets.actionOid
            let groups = try await services.nodeQuery.getAttributes(oid: scrollOid, sessionId: sessionId)
            let node = rehydratedNode(baseNode, attributeGroups: groups)
            let resolvedTarget = try resolveScrollTarget(for: node)
            let result = try await runScroll(
                services: services,
                sessionId: sessionId,
                node: node,
                scrollOid: scrollOid,
                resolvedTarget: resolvedTarget,
                animated: animated
            )
            OutputFormatter.printAction(result, mode: json ? .json : .human)
        } catch let error as LookinCoreError {
            if json {
                JSONOutput.printError(error: error)
            } else {
                printStderr(error.localizedDescription)
            }
            throw ExitCode(error.exitCode)
        }
    }

    private func resolveScrollTarget(for node: LKNode) throws -> ScrollTargetResolution {
        let absolute = try to.map { try parseCGPoint(argument: $0, label: "scroll") }
        let delta = try by.map { try parseCGPoint(argument: $0, label: "scroll") }

        if absolute == nil && delta == nil {
            throw LookinCoreError.actionFailed(action: "scroll", reason: "Provide either --to x,y or --by dx,dy.")
        }
        if absolute != nil && delta != nil {
            throw LookinCoreError.actionFailed(action: "scroll", reason: "Use only one of --to or --by.")
        }
        if let absolute {
            let metrics = try scrollMetrics(for: node)
            return ScrollTargetResolution(
                requestedOffset: absolute,
                targetOffset: metrics.clampedOffset(absolute)
            )
        }

        let metrics = try scrollMetrics(for: node)
        let current = metrics.contentOffset
        let deltaPoint = delta ?? .zero
        let requested = CGPoint(x: current.x + deltaPoint.x, y: current.y + deltaPoint.y)
        return ScrollTargetResolution(
            requestedOffset: requested,
            targetOffset: metrics.clampedOffset(requested)
        )
    }

    private func currentContentOffset(for node: LKNode) throws -> CGPoint {
        try scrollMetrics(for: node).contentOffset
    }

    private func scrollMetrics(for node: LKNode) throws -> ScrollMetrics {
        let acceptedKeys = Set(["contentOffset", "sv_o_o"])
        let groups = node.attributeGroups ?? []
        var contentOffset: CGPoint?
        var contentSize: CGSize?
        var viewportSize = viewportSize(from: node)
        var adjustedContentInset: ScrollInsets = .zero

        for group in groups {
            for attribute in group.attributes {
                let names = Set([attribute.key, attribute.displayName])
                let value = attribute.value.stringValue
                if !acceptedKeys.isDisjoint(with: names) {
                    contentOffset = try parseCGPoint(argument: value, label: "contentOffset")
                } else if names.contains("contentSize") || names.contains("sv_c_s") {
                    contentSize = try? parseCGSize(argument: value, label: "contentSize")
                } else if names.contains("bounds") || names.contains("l_b_b") {
                    if let rect = try? parseCGRect(argument: value, label: "bounds"), rect.width > 0, rect.height > 0 {
                        viewportSize = rect.size
                    }
                } else if names.contains("frame") || names.contains("l_f_f") {
                    if viewportSize == nil,
                       let rect = try? parseCGRect(argument: value, label: "frame"),
                       rect.width > 0,
                       rect.height > 0 {
                        viewportSize = rect.size
                    }
                } else if names.contains("adjustedContentInset") || names.contains("sv_a_i") {
                    adjustedContentInset = (try? parseScrollInsets(argument: value, label: "adjustedContentInset")) ?? .zero
                }
            }
        }
        if let contentOffset {
            return ScrollMetrics(
                contentOffset: contentOffset,
                contentSize: contentSize,
                viewportSize: viewportSize,
                adjustedContentInset: adjustedContentInset
            )
        }
        throw LookinCoreError.actionFailed(
            action: "scroll",
            reason: "\(node.className)(oid:\(node.oid)) does not expose contentOffset. Target a UIScrollView node."
        )
    }

    private func viewportSize(from node: LKNode) -> CGSize? {
        if node.bounds.width > 0, node.bounds.height > 0 {
            return CGSize(width: node.bounds.width, height: node.bounds.height)
        }
        if node.frame.width > 0, node.frame.height > 0 {
            return CGSize(width: node.frame.width, height: node.frame.height)
        }
        return nil
    }

    private func runScroll(
        services: ServiceContainer,
        sessionId: String,
        node: LKNode,
        scrollOid: UInt,
        resolvedTarget: ScrollTargetResolution,
        animated: Bool
    ) async throws -> LKActionResult {
        switch mode {
        case .semantic:
            return try await semanticScroll(
                services: services,
                sessionId: sessionId,
                node: node,
                scrollOid: scrollOid,
                resolvedTarget: resolvedTarget,
                animated: animated
            )
        case .physical:
            throw unsupportedPhysicalAction("scroll")
        case .auto:
            return try await semanticScroll(
                services: services,
                sessionId: sessionId,
                node: node,
                scrollOid: scrollOid,
                resolvedTarget: resolvedTarget,
                animated: animated
            )
        }
    }

    private func semanticScroll(
        services: ServiceContainer,
        sessionId: String,
        node: LKNode,
        scrollOid: UInt,
        resolvedTarget: ScrollTargetResolution,
        animated: Bool
    ) async throws -> LKActionResult {
        let targetOffset = resolvedTarget.targetOffset
        if animated {
            _ = try await services.mutation.scrollAnimated(nodeOid: scrollOid, targetOffset: targetOffset, sessionId: sessionId)
            return LKActionResult(
                action: "scroll",
                nodeOid: scrollOid,
                targetClass: node.className,
                mode: .semantic,
                success: true,
                detail: scrollDetail(actualOffset: targetOffset, resolvedTarget: resolvedTarget, animated: true)
            )
        }
        let value = formatCGPoint(targetOffset)
        _ = try await services.mutation.setAttribute(
            nodeOid: scrollOid,
            key: "contentOffset",
            value: value,
            sessionId: sessionId
        )
        let refreshedGroups = try await services.nodeQuery.getAttributes(oid: scrollOid, sessionId: sessionId)
        let refreshedNode = rehydratedNode(node, attributeGroups: refreshedGroups)
        let actualOffset = try currentContentOffset(for: refreshedNode)
        guard abs(actualOffset.x - targetOffset.x) < 0.5, abs(actualOffset.y - targetOffset.y) < 0.5 else {
            throw LookinCoreError.actionFailed(
                action: "scroll",
                reason: "Requested contentOffset \(value), but UIScrollView now reports \(formatCGPoint(actualOffset))."
            )
        }
        return LKActionResult(
            action: "scroll",
            nodeOid: scrollOid,
            targetClass: node.className,
            mode: .semantic,
            success: true,
            detail: scrollDetail(actualOffset: actualOffset, resolvedTarget: resolvedTarget, animated: false)
        )
    }

    private func scrollDetail(
        actualOffset: CGPoint,
        resolvedTarget: ScrollTargetResolution,
        animated: Bool
    ) -> String {
        var detail = "contentOffset -> \(formatCGPoint(actualOffset))"
        if resolvedTarget.didClamp {
            detail += " (clamped from \(formatCGPoint(resolvedTarget.requestedOffset)))"
        }
        if animated {
            detail += " (animated)"
        }
        return detail
    }

    private func rehydratedNode(_ baseNode: LKNode, attributeGroups: [LKAttributeGroup]) -> LKNode {
        LKNode(
            oid: baseNode.oid,
            primaryOid: baseNode.primaryOid,
            oidType: baseNode.oidType,
            viewOid: baseNode.viewOid,
            layerOid: baseNode.layerOid,
            className: baseNode.className,
            address: baseNode.address,
            frame: baseNode.frame,
            bounds: baseNode.bounds,
            isHidden: baseNode.isHidden,
            alpha: baseNode.alpha,
            isUserInteractionEnabled: baseNode.isUserInteractionEnabled,
            backgroundColor: baseNode.backgroundColor,
            tag: baseNode.tag,
            accessibilityLabel: baseNode.accessibilityLabel,
            accessibilityIdentifier: baseNode.accessibilityIdentifier,
            hostViewControllerClassName: baseNode.hostViewControllerClassName,
            hostViewControllerOid: baseNode.hostViewControllerOid,
            layerClassName: baseNode.layerClassName,
            clipsToBounds: baseNode.clipsToBounds,
            isOpaque: baseNode.isOpaque,
            contentMode: baseNode.contentMode,
            customDisplayTitle: baseNode.customDisplayTitle,
            depth: baseNode.depth,
            parentOid: baseNode.parentOid,
            childrenOids: baseNode.childrenOids,
            attributeGroups: attributeGroups
        )
    }
}
