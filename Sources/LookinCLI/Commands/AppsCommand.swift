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

    @Flag(name: .long, help: "Show per-port probe diagnostics when discovery fails")
    var verbose = false

    @Flag(name: .long, help: "Use mock data instead of live connection")
    var mock = false

    mutating func run() async throws {
        let services = ServiceContainer.make(live: !mock)
        defer { services.shutdown() }
        do {
            let apps = try await services.session.discoverApps()
            OutputFormatter.printApps(apps, mode: json ? .json : .human)
        } catch let error as LookinCoreError {
            if verbose, !mock, let liveSession = services.session as? LiveSessionService {
                let probes = await liveSession.probeDiscovery()
                OutputFormatter.printDiscoveryProbes(probes, mode: json ? .json : .human)
            } else if json {
                JSONOutput.printError(error: error)
            } else {
                printStderr(error.localizedDescription)
            }
            throw ExitCode(error.exitCode)
        }
    }
}
