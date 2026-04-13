import ArgumentParser
import LookinCore

struct TapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Trigger a semantic tap on a node"
    )

    @Argument(help: "Target node OID")
    var nodeId: UInt

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
            let result = try await runTap(services: services, sessionId: sessionId, nodeId: nodeId)
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

    private func runTap(
        services: ServiceContainer,
        sessionId: String,
        nodeId: UInt
    ) async throws -> LKActionResult {
        switch mode {
        case .semantic, .auto:
            return try await services.mutation.triggerTap(nodeOid: nodeId, sessionId: sessionId)
        case .physical:
            throw unsupportedPhysicalAction("tap")
        }
    }
}
