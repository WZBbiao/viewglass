import Foundation
import ArgumentParser
import LookinCore

struct WaitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Poll until a UI condition is met or a timeout elapses",
        subcommands: [WaitAppears.self, WaitGone.self]
    )
}

struct WaitSharedOptions: ParsableArguments {
    @Option(name: .long, help: "Maximum seconds to wait (default: 10)")
    var timeout: Double = 10.0

    @Option(name: .long, help: "Polling interval in milliseconds (default: 500)")
    var intervalMs: Int = 500

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false
}

struct WaitAppears: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appears",
        abstract: "Wait until at least one node matching the locator is found"
    )

    @Argument(help: "Locator: class name, OID, accessibility label, or query expression")
    var locator: String

    @OptionGroup var shared: WaitSharedOptions

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(shared.session, services: services)
            let result = try await poll(
                condition: "appears:\(locator)",
                sessionId: sessionId,
                services: services,
                timeout: shared.timeout,
                intervalMs: shared.intervalMs
            ) { count in count > 0 }
            OutputFormatter.printWaitResult(result, mode: shared.json ? .json : .human)
            if !result.met {
                throw ExitCode(1)
            }
        } catch let error as LookinCoreError {
            if shared.json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}

struct WaitGone: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gone",
        abstract: "Wait until no nodes matching the locator remain visible"
    )

    @Argument(help: "Locator: class name, OID, accessibility label, or query expression")
    var locator: String

    @OptionGroup var shared: WaitSharedOptions

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(shared.session, services: services)
            let result = try await poll(
                condition: "gone:\(locator)",
                sessionId: sessionId,
                services: services,
                timeout: shared.timeout,
                intervalMs: shared.intervalMs
            ) { count in count == 0 }
            OutputFormatter.printWaitResult(result, mode: shared.json ? .json : .human)
            if !result.met {
                throw ExitCode(1)
            }
        } catch let error as LookinCoreError {
            if shared.json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}

// MARK: - Shared polling logic

private func poll(
    condition: String,
    sessionId: String,
    services: ServiceContainer,
    timeout: Double,
    intervalMs: Int,
    satisfied: (Int) -> Bool
) async throws -> LKWaitResult {
    let start = Date()
    var pollCount = 0
    var lastMatchCount = 0

    // Extract the raw locator string (strip "appears:" / "gone:" prefix)
    let rawLocator = String(condition.drop(while: { $0 != ":" }).dropFirst())

    while true {
        let resolved = try await services.nodeQuery.resolve(
            locator: .parse(rawLocator),
            sessionId: sessionId
        )
        pollCount += 1
        lastMatchCount = resolved.matches.count

        let elapsedSeconds = Date().timeIntervalSince(start)

        if satisfied(lastMatchCount) {
            return LKWaitResult(
                condition: condition,
                met: true,
                elapsedSeconds: elapsedSeconds,
                pollCount: pollCount,
                matchCount: lastMatchCount
            )
        }

        if elapsedSeconds >= timeout {
            return LKWaitResult(
                condition: condition,
                met: false,
                elapsedSeconds: elapsedSeconds,
                pollCount: pollCount,
                matchCount: lastMatchCount
            )
        }

        try await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
    }
}
