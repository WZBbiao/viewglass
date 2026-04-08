import ArgumentParser
import LookinCore

struct SelectCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "select",
        abstract: "Select a node in the running app for inspection"
    )

    @Argument(help: "Node OID to select")
    var nodeId: UInt

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let node = try await services.nodeQuery.selectNode(oid: nodeId, sessionId: session)
            if json {
                JSONOutput.print(SelectResult(
                    success: true,
                    selectedOid: node.oid,
                    className: node.className
                ))
            } else {
                print("Selected: \(node.className) (oid:\(node.oid))")
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

struct SelectResult: Codable {
    let success: Bool
    let selectedOid: UInt
    let className: String
}
