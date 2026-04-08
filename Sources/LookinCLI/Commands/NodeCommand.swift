import ArgumentParser
import LookinCore

struct NodeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "node",
        abstract: "Inspect individual nodes",
        subcommands: [NodeGet.self],
        defaultSubcommand: NodeGet.self
    )
}

struct NodeGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get detailed information about a specific node"
    )

    @Argument(help: "Node OID (object identifier)")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let node = try await services.nodeQuery.getNode(oid: nodeId, sessionId: session)
            OutputFormatter.printNode(node, mode: json ? .json : .human)
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
