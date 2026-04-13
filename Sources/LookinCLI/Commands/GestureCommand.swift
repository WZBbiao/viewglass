import ArgumentParser
import LookinCore

struct GestureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gesture",
        abstract: "Inspect gesture recognizers attached to a node",
        subcommands: [
            GestureListCommand.self,
            GestureInspectCommand.self,
        ]
    )
}

struct GestureListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List gesture recognizers attached to a node"
    )

    @Argument(help: "Target node OID")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        try await runGestureInspection(includeRaw: false)
    }

    fileprivate func runGestureInspection(includeRaw: Bool) async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }

        do {
            let sessionId = try resolveSession(session, services: services)
            var result = try await services.mutation.inspectGestures(nodeOid: nodeId, sessionId: sessionId)
            if !includeRaw {
                result = LKGestureInspectionResult(
                    nodeOid: result.nodeOid,
                    targetClass: result.targetClass,
                    gestures: result.gestures,
                    rawValue: ""
                )
            }
            OutputFormatter.printGestureInspection(result, mode: json ? .json : .human)
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

struct GestureInspectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect gesture recognizers with raw recognizer payload"
    )

    @Argument(help: "Target node OID")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        var list = GestureListCommand()
        list.nodeId = nodeId
        list.session = session
        list.json = json
        try await list.runGestureInspection(includeRaw: true)
    }
}
