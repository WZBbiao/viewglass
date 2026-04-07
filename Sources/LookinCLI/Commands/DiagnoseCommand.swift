import ArgumentParser
import LookinCore

struct DiagnoseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagnose",
        abstract: "Run diagnostic checks on the view hierarchy",
        subcommands: [
            DiagnoseOverlap.self,
            DiagnoseHiddenInteractive.self,
            DiagnoseOffscreen.self,
            DiagnoseAll.self,
        ]
    )
}

struct DiagnoseOverlap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "overlap",
        abstract: "Find overlapping interactive views"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            let result = services.diagnostics.diagnoseOverlap(snapshot: snapshot)
            OutputFormatter.printDiagnostic(result, mode: json ? .json : .human)
            if result.hasIssues {
                throw ExitCode(1)
            }
        } catch is ExitCode {
            throw ExitCode(1)
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

struct DiagnoseHiddenInteractive: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hidden-interactive",
        abstract: "Find interactive views that are hidden or invisible"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            let result = services.diagnostics.diagnoseHiddenInteractive(snapshot: snapshot)
            OutputFormatter.printDiagnostic(result, mode: json ? .json : .human)
            if result.hasIssues {
                throw ExitCode(1)
            }
        } catch is ExitCode {
            throw ExitCode(1)
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

struct DiagnoseOffscreen: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "offscreen",
        abstract: "Find views that are completely offscreen"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            let result = services.diagnostics.diagnoseOffscreen(snapshot: snapshot)
            OutputFormatter.printDiagnostic(result, mode: json ? .json : .human)
            if result.hasIssues {
                throw ExitCode(1)
            }
        } catch is ExitCode {
            throw ExitCode(1)
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

struct DiagnoseAll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "all",
        abstract: "Run all diagnostic checks"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeMock()
        do {
            let snapshot = try await services.hierarchy.fetchHierarchy(sessionId: session)
            let results = [
                services.diagnostics.diagnoseOverlap(snapshot: snapshot),
                services.diagnostics.diagnoseHiddenInteractive(snapshot: snapshot),
                services.diagnostics.diagnoseOffscreen(snapshot: snapshot),
            ]
            if json {
                JSONOutput.print(results)
            } else {
                for result in results {
                    OutputFormatter.printDiagnostic(result, mode: .human)
                    print("")
                }
            }
            if results.contains(where: \.hasIssues) {
                throw ExitCode(1)
            }
        } catch is ExitCode {
            throw ExitCode(1)
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
