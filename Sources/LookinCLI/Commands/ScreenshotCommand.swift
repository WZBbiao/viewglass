import ArgumentParser
import LookinCore

struct ScreenshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture screenshots",
        subcommands: [ScreenshotScreen.self, ScreenshotNode.self]
    )
}

struct ScreenshotScreen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screen",
        abstract: "Capture a full screen screenshot"
    )

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "screen.png"

    @Option(name: .long, help: "Explicit simulator or device UDID to capture from")
    var udid: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let ref = try await services.screenshot.captureScreen(
                sessionId: try resolveSession(session, services: services),
                outputPath: output,
                preferredDeviceIdentifier: udid
            )
            OutputFormatter.printScreenshot(ref, mode: json ? .json : .human)
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

struct ScreenshotNode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "node",
        abstract: "Capture a screenshot of a specific node"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "node.png"

    @Option(name: .long, help: "Explicit simulator or device UDID to capture from")
    var udid: String?

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
                action: "capture-target",
                capability: "capture"
            )
            let ref = try await services.screenshot.captureNode(
                oid: resolved.targets.captureOid,
                sessionId: sessionId,
                outputPath: output,
                preferredDeviceIdentifier: udid
            )
            OutputFormatter.printScreenshot(ref, mode: json ? .json : .human)
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
