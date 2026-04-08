import ArgumentParser
import LookinCore

struct QueryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query nodes by expression"
    )

    @Argument(help: "Query expression (e.g. 'UILabel', '.visible AND UIButton', 'oid:123')")
    var expression: String

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Show only count of matching nodes")
    var count = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let nodes = try await services.nodeQuery.queryNodes(expression: expression, sessionId: session)
            if count {
                if json {
                    JSONOutput.print(QueryCountResult(expression: expression, count: nodes.count))
                } else {
                    print("\(nodes.count)")
                }
            } else {
                OutputFormatter.printNodes(nodes, mode: json ? .json : .human)
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

struct QueryCountResult: Codable {
    let expression: String
    let count: Int
}
