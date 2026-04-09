import ArgumentParser
import LookinCore

struct TapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Trigger a semantic tap on a node"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

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
            let result = try await runTap(services: services, sessionId: sessionId, target: target)
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
        target: String
    ) async throws -> LKActionResult {
        let resolved = try await resolveActionTarget(
            target,
            services: services,
            sessionId: sessionId,
            action: "tap",
            capability: "tap"
        )
        switch mode {
        case .semantic, .auto:
            return try await services.mutation.triggerTap(nodeOid: resolved.targets.actionOid, sessionId: sessionId)
        case .physical:
            throw unsupportedPhysicalAction("tap")
        }
    }
}
