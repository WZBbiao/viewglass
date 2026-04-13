import Foundation

public final class MockExportService: ExportServiceProtocol, @unchecked Sendable {
    public var shouldFail = false
    public var lastExportedPath: String?

    public init() {}

    public func exportHierarchy(
        snapshot: LKHierarchySnapshot,
        format: ExportFormat,
        outputPath: String
    ) async throws -> String {
        if shouldFail { throw LookinCoreError.exportFailed(reason: "Mock failure") }

        let content: String
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            content = String(data: data, encoding: .utf8) ?? "{}"
        case .text:
            content = HierarchyTextFormatter.format(snapshot: snapshot)
        case .html:
            content = HierarchyTextFormatter.formatHTML(snapshot: snapshot)
        }

        try content.write(toFile: outputPath, atomically: true, encoding: .utf8)
        lastExportedPath = outputPath
        return outputPath
    }

    public func exportReport(
        snapshot: LKHierarchySnapshot,
        outputPath: String
    ) async throws -> String {
        if shouldFail { throw LookinCoreError.exportFailed(reason: "Mock failure") }
        let report = ReportGenerator.generate(snapshot: snapshot)
        try report.write(toFile: outputPath, atomically: true, encoding: .utf8)
        lastExportedPath = outputPath
        return outputPath
    }
}

public enum HierarchyTextFormatter {
    public static func format(snapshot: LKHierarchySnapshot) -> String {
        var lines: [String] = []
        lines.append("App: \(snapshot.appInfo.appName) (\(snapshot.appInfo.bundleIdentifier))")
        lines.append("Nodes: \(snapshot.totalNodeCount)")
        lines.append("Screen: \(Int(snapshot.screenSize.width))x\(Int(snapshot.screenSize.height)) @\(snapshot.screenScale)x")
        lines.append("")
        for window in snapshot.windows {
            formatTree(window, indent: 0, lines: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private static func formatTree(_ tree: LKNodeTree, indent: Int, lines: inout [String]) {
        let prefix = String(repeating: "  ", count: indent)
        let visibility = tree.node.isVisible ? "" : " [hidden]"
        let frame = tree.node.frame
        lines.append("\(prefix)\(tree.node.displayTitle) (oid:\(tree.node.oid)) frame:(\(Int(frame.x)),\(Int(frame.y)),\(Int(frame.width)),\(Int(frame.height)))\(visibility)")
        for child in tree.children {
            formatTree(child, indent: indent + 1, lines: &lines)
        }
    }

    public static func formatHTML(snapshot: LKHierarchySnapshot) -> String {
        var html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(snapshot.appInfo.appName) Hierarchy</title>
        <style>body{font-family:monospace;font-size:13px}
        .node{margin-left:20px}.hidden{opacity:0.5}
        .class{color:#2196F3}.oid{color:#999}.frame{color:#4CAF50}</style></head><body>
        <h2>\(snapshot.appInfo.appName) (\(snapshot.appInfo.bundleIdentifier))</h2>
        <p>Nodes: \(snapshot.totalNodeCount) | Screen: \(Int(snapshot.screenSize.width))x\(Int(snapshot.screenSize.height)) @\(snapshot.screenScale)x</p>
        """
        for window in snapshot.windows {
            html += formatTreeHTML(window)
        }
        html += "</body></html>"
        return html
    }

    private static func formatTreeHTML(_ tree: LKNodeTree) -> String {
        let hiddenClass = tree.node.isVisible ? "" : " hidden"
        let frame = tree.node.frame
        var html = """
        <div class="node\(hiddenClass)">
        <span class="class">\(tree.node.displayTitle)</span>
        <span class="oid">(oid:\(tree.node.oid))</span>
        <span class="frame">(\(Int(frame.x)),\(Int(frame.y)),\(Int(frame.width)),\(Int(frame.height)))</span>
        """
        for child in tree.children {
            html += formatTreeHTML(child)
        }
        html += "</div>"
        return html
    }
}

public enum ReportGenerator {
    public static func generate(snapshot: LKHierarchySnapshot) -> String {
        let nodes = snapshot.flatNodes
        let visibleNodes = nodes.filter(\.isVisible)
        let hiddenNodes = nodes.filter { !$0.isVisible }
        let interactiveNodes = nodes.filter(\.isUserInteractionEnabled)

        var classCount: [String: Int] = [:]
        for node in nodes {
            classCount[node.className, default: 0] += 1
        }
        let sortedClasses = classCount.sorted { $0.value > $1.value }

        var lines: [String] = []
        lines.append("# Lookin Hierarchy Report")
        lines.append("")
        lines.append("## App Info")
        lines.append("- Name: \(snapshot.appInfo.appName)")
        lines.append("- Bundle ID: \(snapshot.appInfo.bundleIdentifier)")
        lines.append("- Version: \(snapshot.appInfo.appVersion ?? "N/A")")
        lines.append("- Device: \(snapshot.appInfo.deviceName ?? "N/A")")
        lines.append("- Server: \(snapshot.serverVersion ?? "N/A")")
        lines.append("")
        lines.append("## Summary")
        lines.append("- Total nodes: \(nodes.count)")
        lines.append("- Visible nodes: \(visibleNodes.count)")
        lines.append("- Hidden nodes: \(hiddenNodes.count)")
        lines.append("- Interactive nodes: \(interactiveNodes.count)")
        lines.append("- Window count: \(snapshot.windows.count)")
        lines.append("- Screen: \(Int(snapshot.screenSize.width))x\(Int(snapshot.screenSize.height)) @\(snapshot.screenScale)x")
        lines.append("")
        lines.append("## Class Distribution")
        for (className, count) in sortedClasses {
            lines.append("- \(className): \(count)")
        }
        return lines.joined(separator: "\n")
    }
}
