import ArgumentParser
import LookinCore

struct HierarchyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hierarchy",
        abstract: "Fetch and display view hierarchy",
        subcommands: [HierarchyDump.self],
        defaultSubcommand: HierarchyDump.self
    )
}

struct HierarchyDump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump the full view hierarchy"
    )

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Compact output optimised for AI agent consumption (oid/class/label/frame only)")
    var compact = false

    @Option(name: .long, help: "Maximum depth to display")
    var maxDepth: Int?

    @Option(name: .long, help: "Filter to nodes matching this locator expression (keeps ancestor path for context)")
    var filter: String?

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            var snapshot = try await services.hierarchy.fetchHierarchy(sessionId: try resolveSession(session, services: services))
            if let maxDepth = maxDepth {
                snapshot = filterByDepth(snapshot, maxDepth: maxDepth)
            }
            if let locator = filter {
                snapshot = try filterByLocator(snapshot, locator: locator)
            }
            if compact {
                OutputFormatter.printHierarchyCompact(snapshot, mode: json ? .json : .human)
            } else {
                OutputFormatter.printHierarchy(snapshot, mode: json ? .json : .human)
            }
        } catch let error as LookinCoreError {
            if json {
                JSONOutput.printError(error: error)
            } else {
                printStderr(error.localizedDescription)
            }
            throw ExitCode(error.exitCode)
        }
    }

    private func filterByDepth(_ snapshot: LKHierarchySnapshot, maxDepth: Int) -> LKHierarchySnapshot {
        let filtered = snapshot.windows.map { pruneTree($0, currentDepth: 0, maxDepth: maxDepth) }
        return LKHierarchySnapshot(
            appInfo: snapshot.appInfo,
            windows: filtered,
            fetchedAt: snapshot.fetchedAt,
            serverVersion: snapshot.serverVersion,
            screenScale: snapshot.screenScale,
            screenSize: snapshot.screenSize
        )
    }

    private func pruneTree(_ tree: LKNodeTree, currentDepth: Int, maxDepth: Int) -> LKNodeTree {
        if currentDepth >= maxDepth {
            return LKNodeTree(node: tree.node, children: [])
        }
        let children = tree.children.map { pruneTree($0, currentDepth: currentDepth + 1, maxDepth: maxDepth) }
        return LKNodeTree(node: tree.node, children: children)
    }

    private func filterByLocator(_ snapshot: LKHierarchySnapshot, locator: String) throws -> LKHierarchySnapshot {
        try snapshot.filtered(matching: locator)
    }
}
