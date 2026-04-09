import ArgumentParser
import LookinCore

struct LocateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "locate",
        abstract: "Resolve a locator into candidate targets"
    )

    @Argument(help: "Locator expression")
    var locator: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }

        do {
            let resolved = try await services.nodeQuery.resolve(
                locator: .parse(locator),
                sessionId: try resolveSession(session, services: services)
            )
            if json {
                JSONOutput.print(resolved)
            } else {
                OutputFormatter.printNodes(resolved.matches.map(\.node), mode: .human)
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
