import ArgumentParser
import LookinCore

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan for inspectable apps and optionally show probe diagnostics"
    )

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Show per-port probe diagnostics")
    var verbose = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            if verbose, let liveSession = services.session as? LiveSessionService {
                let probes = await liveSession.probeDiscovery()
                let apps = probes.compactMap(\.app)
                if apps.isEmpty {
                    OutputFormatter.printDiscoveryProbes(probes, mode: json ? .json : .human)
                    throw ExitCode(10)
                }
                OutputFormatter.printDiscoveryProbes(probes, mode: json ? .json : .human)
                return
            }

            let apps = try await services.session.discoverApps()
            OutputFormatter.printApps(apps, mode: json ? .json : .human)
        } catch let error as LookinCoreError {
            if json {
                JSONOutput.printError(error: error)
            } else {
                printStderr("No inspectable apps found on simulator ports 47164-47169.")
                printStderr("Ensure your iOS app has LookinServer integrated and is running in the simulator or on a USB-connected device.")
                printStderr("Use `viewglass scan --verbose` for per-port diagnostics.")
            }
            throw ExitCode(error.exitCode)
        }
    }
}
