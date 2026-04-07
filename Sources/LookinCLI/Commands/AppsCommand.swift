import ArgumentParser
import LookinCore

struct AppsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "Discover and list inspectable iOS apps",
        subcommands: [AppsList.self],
        defaultSubcommand: AppsList.self
    )
}

struct AppsList: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all inspectable apps on connected devices and simulators"
    )

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let apps = try await services.session.discoverApps()
            OutputFormatter.printApps(apps, mode: json ? .json : .human)
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
