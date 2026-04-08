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

    @Option(name: .long, help: "Target node OID")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let result = try await services.mutation.invokeMethod(
                nodeOid: nodeId,
                selector: expression,
                sessionId: session
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
