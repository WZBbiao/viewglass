import ArgumentParser
import LookinCore

struct DismissCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dismiss",
        abstract: "Dismiss a UIViewController target or a node hosted by one"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }

        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                target,
                services: services,
                sessionId: sessionId,
                action: "dismiss",
                capability: "dismiss"
            )
            let targetOid = resolved.targets.controllerOid ?? resolved.targets.actionOid
            let result = try await services.mutation.triggerDismiss(nodeOid: targetOid, sessionId: sessionId)
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
}
