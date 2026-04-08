import ArgumentParser
import LookinCore

struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export hierarchy data to files",
        subcommands: [ExportHierarchy.self, ExportReport.self]
    )
}

struct ExportHierarchy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hierarchy",
        abstract: "Export hierarchy as JSON, text, or HTML"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "hierarchy.json"

    @Option(name: .long, help: "Export format (json, text, html)")
    var format: String = "json"

    @Flag(name: .long, help: "Output result metadata in JSON")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            guard let exportFormat = ExportFormat(rawValue: format) else {
                let msg = "Invalid format '\(format)'. Use: json, text, html"
                if json {
                    JSONOutput.printError(message: msg, code: 60)
                } else {
                    printStderr(msg)
                }
                throw ExitCode(60)
            }
            let path = try await services.export.exportHierarchy(
                snapshot: snapshot,
                format: exportFormat,
                outputPath: output
            )
            if json {
                JSONOutput.print(ExportResult(
                    success: true,
                    outputPath: path,
                    format: format,
                    nodeCount: snapshot.totalNodeCount
                ))
            } else {
                print("Exported \(snapshot.totalNodeCount) nodes to \(path) (\(format))")
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

struct ExportReport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate a summary report of the hierarchy"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Option(name: .shortAndLong, help: "Output file path")
    var output: String = "report.md"

    @Flag(name: .long, help: "Output result metadata in JSON")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            let path = try await services.export.exportReport(snapshot: snapshot, outputPath: output)
            if json {
                JSONOutput.print(ExportResult(
                    success: true,
                    outputPath: path,
                    format: "markdown",
                    nodeCount: snapshot.totalNodeCount
                ))
            } else {
                print("Report generated: \(path)")
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

struct ExportResult: Codable {
    let success: Bool
    let outputPath: String
    let format: String
    let nodeCount: Int
}
