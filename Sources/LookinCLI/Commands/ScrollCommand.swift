import ArgumentParser
import CoreGraphics
import LookinCore

struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll a UIScrollView node using semantic actions"
    )

    @Argument(help: "Target node OID")
    var nodeId: UInt

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

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }

        do {
            let sessionId = try resolveSession(session, services: services)
            let baseNode = try await services.nodeQuery.getNode(oid: nodeId, sessionId: sessionId)
            let needsAttributes = by != nil
            let groups = needsAttributes ? try await services.nodeQuery.getAttributes(oid: nodeId, sessionId: sessionId) : []
            let node = LKNode(
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
                attributeGroups: groups
            )
            let resolvedOffset = try resolveTargetOffset(for: node)
            let result = try await runScroll(
                services: services,
                sessionId: sessionId,
                node: node,
                targetOffset: resolvedOffset
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

    private func resolveTargetOffset(for node: LKNode) throws -> CGPoint {
        let absolute = try to.map { try parseCGPoint(argument: $0, label: "scroll") }
        let delta = try by.map { try parseCGPoint(argument: $0, label: "scroll") }

        if absolute == nil && delta == nil {
            throw LookinCoreError.actionFailed(action: "scroll", reason: "Provide either --to x,y or --by dx,dy.")
        }
        if absolute != nil && delta != nil {
            throw LookinCoreError.actionFailed(action: "scroll", reason: "Use only one of --to or --by.")
        }
        if let absolute {
            return absolute
        }

        let current = try currentContentOffset(for: node)
        let deltaPoint = delta ?? .zero
        return CGPoint(x: current.x + deltaPoint.x, y: current.y + deltaPoint.y)
    }

    private func currentContentOffset(for node: LKNode) throws -> CGPoint {
        let acceptedKeys = Set(["contentOffset", "sv_o_o"])
        let groups = node.attributeGroups ?? []
        for group in groups {
            for attribute in group.attributes where
                acceptedKeys.contains(attribute.key) ||
                acceptedKeys.contains(attribute.displayName)
            {
                return try parseCGPoint(argument: attribute.value.stringValue, label: "contentOffset")
            }
        }
        throw LookinCoreError.actionFailed(
            action: "scroll",
            reason: "\(node.className)(oid:\(node.oid)) does not expose contentOffset. Target a UIScrollView node."
        )
    }

    private func runScroll(
        services: ServiceContainer,
        sessionId: String,
        node: LKNode,
        targetOffset: CGPoint
    ) async throws -> LKActionResult {
        switch mode {
        case .semantic:
            return try await semanticScroll(services: services, sessionId: sessionId, node: node, targetOffset: targetOffset)
        case .physical:
            throw unsupportedPhysicalAction("scroll")
        case .auto:
            return try await semanticScroll(services: services, sessionId: sessionId, node: node, targetOffset: targetOffset)
        }
    }

    private func semanticScroll(
        services: ServiceContainer,
        sessionId: String,
        node: LKNode,
        targetOffset: CGPoint
    ) async throws -> LKActionResult {
        let value = formatCGPoint(targetOffset)
        _ = try await services.mutation.setAttribute(
            nodeOid: node.oid,
            key: "contentOffset",
            value: value,
            sessionId: sessionId
        )
        let refreshedGroups = try await services.nodeQuery.getAttributes(oid: node.oid, sessionId: sessionId)
        let refreshedNode = LKNode(
            oid: node.oid,
            primaryOid: node.primaryOid,
            oidType: node.oidType,
            viewOid: node.viewOid,
            layerOid: node.layerOid,
            className: node.className,
            address: node.address,
            frame: node.frame,
            bounds: node.bounds,
            isHidden: node.isHidden,
            alpha: node.alpha,
            isUserInteractionEnabled: node.isUserInteractionEnabled,
            backgroundColor: node.backgroundColor,
            tag: node.tag,
            accessibilityLabel: node.accessibilityLabel,
            accessibilityIdentifier: node.accessibilityIdentifier,
            hostViewControllerClassName: node.hostViewControllerClassName,
            hostViewControllerOid: node.hostViewControllerOid,
            layerClassName: node.layerClassName,
            clipsToBounds: node.clipsToBounds,
            isOpaque: node.isOpaque,
            contentMode: node.contentMode,
            customDisplayTitle: node.customDisplayTitle,
            depth: node.depth,
            parentOid: node.parentOid,
            childrenOids: node.childrenOids,
            attributeGroups: refreshedGroups
        )
        let actualOffset = try currentContentOffset(for: refreshedNode)
        guard abs(actualOffset.x - targetOffset.x) < 0.5, abs(actualOffset.y - targetOffset.y) < 0.5 else {
            throw LookinCoreError.actionFailed(
                action: "scroll",
                reason: "Requested contentOffset \(value), but UIScrollView now reports \(formatCGPoint(actualOffset))."
            )
        }
        return LKActionResult(
            action: "scroll",
            nodeOid: node.oid,
            targetClass: node.className,
            mode: .semantic,
            success: true,
            detail: "contentOffset -> \(formatCGPoint(actualOffset))"
        )
    }
}
