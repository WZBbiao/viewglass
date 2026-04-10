import ArgumentParser
import LookinCore

struct ControlCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "control",
        abstract: "Operate UIControl nodes",
        subcommands: [ControlTap.self]
    )
}

struct ControlTap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Trigger a primary tap on a UIControl node"
    )

    @Argument(help: "Target node OID (e.g. 817 or oid:817)")
    var nodeId: String

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
            let oid = try parseOid(nodeId)
            let sessionId = try resolveSession(session, services: services)
            let node = try await services.nodeQuery.getNode(oid: oid, sessionId: sessionId)
            let result = try await runTap(services: services, sessionId: sessionId, node: node)
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
        node: LKNode
    ) async throws -> LKActionResult {
        switch mode {
        case .semantic:
            return try await services.mutation.triggerControlTap(nodeOid: node.oid, sessionId: sessionId)
        case .physical:
            throw unsupportedPhysicalAction("control-tap")
        case .auto:
            return try await services.mutation.triggerControlTap(nodeOid: node.oid, sessionId: sessionId)
        }
    }
}
