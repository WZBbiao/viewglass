import Foundation

public final class DiagnosticsService: Sendable {

    public init() {}

    public func diagnoseOverlap(snapshot: LKHierarchySnapshot) -> LKDiagnosticResult {
        let nodes = snapshot.flatNodes.filter(\.isVisible)
        var issues: [LKDiagnosticIssue] = []

        // Check sibling nodes for overlap
        for window in snapshot.windows {
            checkSiblingOverlaps(tree: window, issues: &issues)
        }

        return LKDiagnosticResult(
            diagnosticType: .overlap,
            issues: issues,
            summary: issues.isEmpty
                ? "No overlapping interactive views found"
                : "Found \(issues.count) overlapping view pair(s)",
            checkedNodeCount: nodes.count
        )
    }

    private func checkSiblingOverlaps(tree: LKNodeTree, issues: inout [LKDiagnosticIssue]) {
        let visibleChildren = tree.children.filter { $0.node.isVisible }
        let interactiveChildren = visibleChildren.filter { $0.node.isUserInteractionEnabled }

        for i in 0..<interactiveChildren.count {
            for j in (i + 1)..<interactiveChildren.count {
                let a = interactiveChildren[i].node
                let b = interactiveChildren[j].node
                if a.frame.intersects(b.frame) {
                    if let intersection = a.frame.intersection(b.frame) {
                        let overlapArea = intersection.area
                        let smallerArea = min(a.frame.area, b.frame.area)
                        let overlapRatio = smallerArea > 0 ? overlapArea / smallerArea : 0

                        if overlapRatio > 0.1 { // Only flag significant overlaps
                            issues.append(LKDiagnosticIssue(
                                severity: overlapRatio > 0.5 ? .error : .warning,
                                message: "\(a.className)(oid:\(a.oid)) overlaps with \(b.className)(oid:\(b.oid)) — \(Int(overlapRatio * 100))% of smaller view",
                                involvedNodes: [a.oid, b.oid],
                                details: [
                                    "overlapRatio": String(format: "%.2f", overlapRatio),
                                    "overlapRect": "(\(Int(intersection.x)),\(Int(intersection.y)),\(Int(intersection.width)),\(Int(intersection.height)))",
                                ]
                            ))
                        }
                    }
                }
            }
        }

        for child in tree.children {
            checkSiblingOverlaps(tree: child, issues: &issues)
        }
    }

    public func diagnoseHiddenInteractive(snapshot: LKHierarchySnapshot) -> LKDiagnosticResult {
        let nodes = snapshot.flatNodes
        var issues: [LKDiagnosticIssue] = []

        for node in nodes {
            if node.isUserInteractionEnabled && !node.isVisible {
                let reason: String
                if node.isHidden {
                    reason = "isHidden=true"
                } else if node.alpha <= 0 {
                    reason = "alpha=0"
                } else if node.bounds.width <= 0 || node.bounds.height <= 0 {
                    reason = "zero-size bounds"
                } else {
                    reason = "unknown visibility issue"
                }

                issues.append(LKDiagnosticIssue(
                    severity: .warning,
                    message: "\(node.className)(oid:\(node.oid)) is interactive but not visible: \(reason)",
                    involvedNodes: [node.oid],
                    details: [
                        "reason": reason,
                        "className": node.className,
                    ]
                ))
            }
        }

        return LKDiagnosticResult(
            diagnosticType: .hiddenInteractive,
            issues: issues,
            summary: issues.isEmpty
                ? "No hidden interactive views found"
                : "Found \(issues.count) hidden interactive view(s)",
            checkedNodeCount: nodes.count
        )
    }

    public func diagnoseOffscreen(snapshot: LKHierarchySnapshot) -> LKDiagnosticResult {
        let nodes = snapshot.flatNodes.filter(\.isVisible)
        let screenRect = snapshot.screenSize
        var issues: [LKDiagnosticIssue] = []

        for node in nodes where node.frame.area > 0 {
            if !screenRect.intersects(node.frame) && node.depth > 1 {
                issues.append(LKDiagnosticIssue(
                    severity: .info,
                    message: "\(node.className)(oid:\(node.oid)) is completely offscreen",
                    involvedNodes: [node.oid],
                    details: [
                        "frame": "(\(Int(node.frame.x)),\(Int(node.frame.y)),\(Int(node.frame.width)),\(Int(node.frame.height)))",
                    ]
                ))
            }
        }

        return LKDiagnosticResult(
            diagnosticType: .offscreen,
            issues: issues,
            summary: issues.isEmpty
                ? "No offscreen views found"
                : "Found \(issues.count) offscreen view(s)",
            checkedNodeCount: nodes.count
        )
    }
}
