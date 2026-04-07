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

    @Option(name: .long, help: "Session ID")
    var session: String

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "screen.png"

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let ref = try await services.screenshot.captureScreen(sessionId: session, outputPath: output)
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

    @Argument(help: "Node OID")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID")
    var session: String

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "node.png"

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let ref = try await services.screenshot.captureNode(oid: nodeId, sessionId: session, outputPath: output)
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
