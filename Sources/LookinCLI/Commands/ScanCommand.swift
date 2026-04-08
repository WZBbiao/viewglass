import ArgumentParser
import LookinCore

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan for inspectable apps on simulator ports"
    )

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let apps = try await services.session.discoverApps()
            OutputFormatter.printApps(apps, mode: json ? .json : .human)
        } catch {
            if json {
                // Use same error format as all other commands
                JSONOutput.printError(error: .noAppsFound)
            } else {
                printStderr("No inspectable apps found on simulator ports 47164-47169.")
                printStderr("Ensure your iOS app has LookinServer integrated and is running in the simulator.")
            }
            throw ExitCode(10)
        }
    }
}
