import ArgumentParser
import LookinCore

struct ConsoleCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "console",
        abstract: "Evaluate methods on objects in the running app",
        subcommands: [ConsoleEval.self],
        defaultSubcommand: ConsoleEval.self
    )
}

struct ConsoleEval: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "eval",
        abstract: "Invoke a method on an object"
    )

    @Argument(help: "Method selector to invoke (e.g. 'setNeedsLayout')")
    var expression: String

    @Option(name: .long, help: "Target node OID (e.g. 817 or oid:817)")
    var nodeId: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let oid = try parseOid(nodeId)
            let result = try await services.mutation.invokeMethod(
                nodeOid: oid,
                selector: expression,
                args: [],
                sessionId: try resolveSession(session, services: services)
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
