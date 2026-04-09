import ArgumentParser
import LookinCore

struct InputCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "input",
        abstract: "Enter semantic text into a UITextField or UITextView target"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, help: "Text to input")
    var text: String

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
                action: "input",
                capability: "input"
            )
            let result = try await services.mutation.inputText(
                nodeOid: resolved.targets.actionOid,
                text: text,
                sessionId: sessionId
            )
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
