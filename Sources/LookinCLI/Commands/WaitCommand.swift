import Foundation
import ArgumentParser
import LookinCore

struct WaitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Poll until a UI condition is met or a timeout elapses",
        subcommands: [WaitAppears.self, WaitGone.self, WaitAttr.self]
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

struct WaitAttr: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attr",
        abstract: "Wait until a node attribute satisfies a condition"
    )

    @Argument(help: "Locator: class name, OID, accessibility identifier, or query expression")
    var locator: String

    @Option(name: .long, help: "Attribute key to check (same key as 'attr get --json' output)")
    var key: String

    @Option(name: .long, help: "Pass when attribute value equals this string (exact, case-sensitive)")
    var equals: String?

    @Option(name: .long, help: "Pass when attribute value contains this substring (case-insensitive)")
    var contains: String?

    @OptionGroup var shared: WaitSharedOptions

    mutating func run() async throws {
        guard equals != nil || contains != nil else {
            printStderr("Either --equals or --contains must be specified")
            throw ExitCode(1)
        }

        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(shared.session, services: services)

            // Resolve locator once to obtain the target OID.
            let resolved = try await resolveActionTarget(
                locator,
                services: services,
                sessionId: sessionId,
                action: "wait-attr",
                capability: "inspect"
            )
            let targetOid = resolved.targets.inspectOid
            let node = resolved.node

            let start = Date()
            var pollCount = 0
            var met = false

            while true {
                // getAttributes calls fetchHierarchy(forceRefresh: true) internally,
                // so each poll gets live data from the device.
                let groups = try await services.nodeQuery.getAttributes(oid: targetOid, sessionId: sessionId)
                let flat = FlatNodeAttributes.make(oid: node.oid, className: node.className, groups: groups)
                pollCount += 1

                if let attrVal = flat.attributes[key] {
                    let current = attrVal.stringValue
                    let matched: Bool
                    if let eq = equals {
                        matched = current == eq
                    } else {
                        matched = current.localizedCaseInsensitiveContains(contains!)
                    }
                    if matched {
                        met = true
                        break
                    }
                }

                let elapsed = Date().timeIntervalSince(start)
                if elapsed >= shared.timeout { break }
                try await Task.sleep(nanoseconds: UInt64(shared.intervalMs) * 1_000_000)
            }

            let elapsed = Date().timeIntervalSince(start)
            let conditionDesc = equals != nil
                ? "attr:\(key)=\(equals!)"
                : "attr:\(key)~\(contains!)"
            let result = LKWaitResult(
                condition: conditionDesc,
                met: met,
                elapsedSeconds: elapsed,
                pollCount: pollCount,
                matchCount: met ? 1 : 0
            )
            OutputFormatter.printWaitResult(result, mode: shared.json ? .json : .human)
            if !met { throw ExitCode(1) }
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
