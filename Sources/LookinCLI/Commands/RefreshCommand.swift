import ArgumentParser
import LookinCore

struct RefreshCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh",
        abstract: "Refresh the view hierarchy from the connected app"
    )

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let snapshot = try await services.hierarchy.refreshHierarchy(sessionId: try resolveSession(session, services: services))
            if json {
                JSONOutput.print(RefreshResult(
                    success: true,
                    nodeCount: snapshot.totalNodeCount,
                    windowCount: snapshot.windows.count
                ))
            } else {
                print("Hierarchy refreshed: \(snapshot.totalNodeCount) nodes across \(snapshot.windows.count) window(s)")
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
}

struct RefreshResult: Codable {
    let success: Bool
    let nodeCount: Int
    let windowCount: Int
}
