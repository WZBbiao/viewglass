import ArgumentParser
import LookinCore

struct InvokeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoke",
        abstract: "Invoke a no-argument selector on a node"
    )

    @Argument(help: "Method selector to invoke (e.g. 'setNeedsLayout')")
    var selector: String

    @Option(name: .long, help: "Target locator, OID, or resolved-target JSON")
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
                action: "invoke"
            )
            let result = try await services.mutation.invokeMethod(
                nodeOid: resolved.node.hostViewControllerOid ?? resolved.node.primaryOid,
                selector: selector,
                sessionId: sessionId
            )
            OutputFormatter.printConsoleResult(result, mode: json ? .json : .human)
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
