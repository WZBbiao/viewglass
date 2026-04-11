import ArgumentParser
import LookinCore

struct InvokeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoke",
        abstract: "Invoke a selector on a node, optionally with arguments"
    )

    @Argument(help: "Method selector to invoke (e.g. 'setNeedsLayout' or 'setAlpha:')")
    var selector: String

    @Option(name: .long, help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, parsing: .unconditionalSingleValue,
            help: "Argument value (repeat for multiple args, e.g. --arg 0.5). Numeric types, BOOL (YES/NO/true/false/1/0), NSString, and ObjC struct strings ({x,y}, {{x,y},{w,h}}) are supported.")
    var arg: [String] = []

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
                nodeOid: resolved.targets.controllerOid ?? resolved.targets.actionOid,
                selector: selector,
                args: arg,
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
