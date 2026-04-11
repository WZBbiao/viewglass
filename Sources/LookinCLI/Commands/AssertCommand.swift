import ArgumentParser
import LookinCore

struct AssertCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assert",
        abstract: "Assert UI conditions — exits 0 on pass, 1 on failure",
        subcommands: [
            AssertVisible.self,
            AssertText.self,
            AssertCount.self,
            AssertAttr.self,
        ]
    )
}

// MARK: - Shared output

private struct AssertResult: Encodable {
    let passed: Bool
    let assertion: String
    let locator: String
    let matchCount: Int
    let message: String
}

private func printAssertResult(_ result: AssertResult, mode: OutputMode) {
    switch mode {
    case .json:
        JSONOutput.print(result)
    case .human:
        let icon = result.passed ? "✓" : "✗"
        print("\(icon) [\(result.assertion)] \(result.message)")
    }
}

// MARK: - assert visible

struct AssertVisible: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "visible",
        abstract: "Assert at least one node matches the locator and is visible"
    )

    @Argument(help: "Locator: class name, OID, accessibility identifier, or query expression")
    var locator: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await services.nodeQuery.resolve(
                locator: .parse(locator), sessionId: sessionId
            )
            let visible = resolved.matches.filter { $0.node.isVisible }
            let passed = !visible.isEmpty
            let msg: String
            if passed {
                let names = visible.prefix(3).map { "\($0.node.className)(oid:\($0.node.oid))" }.joined(separator: ", ")
                msg = "Found \(visible.count) visible node(s): \(names)"
            } else if resolved.matches.isEmpty {
                msg = "No nodes matched '\(locator)'"
            } else {
                let names = resolved.matches.prefix(3).map { "\($0.node.className)(oid:\($0.node.oid))" }.joined(separator: ", ")
                msg = "\(resolved.matches.count) node(s) matched but none are visible: \(names)"
            }
            let result = AssertResult(passed: passed, assertion: "visible", locator: locator, matchCount: visible.count, message: msg)
            printAssertResult(result, mode: json ? .json : .human)
            if !passed { throw ExitCode(1) }
        } catch let error as LookinCoreError {
            if json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}

// MARK: - assert text

struct AssertText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text",
        abstract: "Assert the first matching node's display text equals (or contains) an expected value"
    )

    @Argument(help: "Locator: class name, OID, accessibility identifier, or query expression")
    var locator: String

    @Argument(help: "Expected text value")
    var expected: String

    @Flag(name: .long, help: "Use substring match instead of exact equality (case-insensitive)")
    var contains = false

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                locator, services: services, sessionId: sessionId, action: "assert-text"
            )
            let node = resolved.node
            // Use customDisplayTitle (UILabel.text etc.) then accessibilityLabel as fallback
            let actual = node.customDisplayTitle ?? node.accessibilityLabel ?? ""
            let passed: Bool
            if contains {
                passed = actual.localizedCaseInsensitiveContains(expected)
            } else {
                passed = actual == expected
            }
            let mode = contains ? "contains" : "=="
            let msg: String
            if passed {
                msg = "\(node.className)(oid:\(node.oid)) text \(mode) '\(expected)' ✓"
            } else {
                msg = "\(node.className)(oid:\(node.oid)) text '\(actual)' does not \(mode) '\(expected)'"
            }
            let result = AssertResult(passed: passed, assertion: "text", locator: locator, matchCount: 1, message: msg)
            printAssertResult(result, mode: json ? .json : .human)
            if !passed { throw ExitCode(1) }
        } catch let error as LookinCoreError {
            if json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}

// MARK: - assert count

struct AssertCount: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "count",
        abstract: "Assert the number of nodes matching the locator"
    )

    @Argument(help: "Locator: class name, OID, accessibility identifier, or query expression")
    var locator: String

    @Argument(help: "Expected exact count (omit when using --min or --max alone)")
    var expected: Int?

    @Option(name: .long, help: "Assert count is at least this value (overrides exact count)")
    var min: Int?

    @Option(name: .long, help: "Assert count is at most this value (overrides exact count)")
    var max: Int?

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await services.nodeQuery.resolve(
                locator: .parse(locator), sessionId: sessionId
            )
            let actual = resolved.matches.count
            let passed: Bool
            let conditionDesc: String
            if let minVal = min, let maxVal = max {
                passed = actual >= minVal && actual <= maxVal
                conditionDesc = "between \(minVal) and \(maxVal)"
            } else if let minVal = min {
                passed = actual >= minVal
                conditionDesc = ">= \(minVal)"
            } else if let maxVal = max {
                passed = actual <= maxVal
                conditionDesc = "<= \(maxVal)"
            } else if let exact = expected {
                passed = actual == exact
                conditionDesc = "== \(exact)"
            } else {
                printStderr("Provide an expected count or at least one of --min / --max")
                throw ExitCode(1)
            }
            let msg: String
            if passed {
                msg = "Found \(actual) node(s) matching '\(locator)' (\(conditionDesc)) ✓"
            } else {
                msg = "Expected \(conditionDesc) node(s) matching '\(locator)', got \(actual)"
            }
            let result = AssertResult(passed: passed, assertion: "count", locator: locator, matchCount: actual, message: msg)
            printAssertResult(result, mode: json ? .json : .human)
            if !passed { throw ExitCode(1) }
        } catch let error as LookinCoreError {
            if json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}

// MARK: - assert attr

struct AssertAttr: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attr",
        abstract: "Assert a node attribute equals (or contains) an expected value"
    )

    @Argument(help: "Locator: class name, OID, accessibility identifier, or query expression")
    var locator: String

    @Option(name: .long, help: "Attribute key to check (same key as 'attr get --json' output)")
    var key: String

    @Option(name: .long, help: "Expected value (exact, case-sensitive)")
    var equals: String?

    @Option(name: .long, help: "Expected substring (case-insensitive)")
    var contains: String?

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        guard equals != nil || contains != nil else {
            printStderr("Either --equals or --contains must be specified")
            throw ExitCode(1)
        }

        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                locator, services: services, sessionId: sessionId,
                action: "assert-attr", capability: "inspect"
            )
            let groups = try await services.nodeQuery.getAttributes(
                oid: resolved.targets.inspectOid, sessionId: sessionId
            )
            let flat = FlatNodeAttributes.make(
                oid: resolved.node.oid, className: resolved.node.className, groups: groups
            )
            guard let attrVal = flat.attributes[key] else {
                let msg = "Attribute '\(key)' not found on \(resolved.node.className)(oid:\(resolved.node.oid))"
                let result = AssertResult(passed: false, assertion: "attr", locator: locator, matchCount: 0, message: msg)
                printAssertResult(result, mode: json ? .json : .human)
                throw ExitCode(1)
            }
            let actual = attrVal.stringValue
            let passed: Bool
            let modeDesc: String
            if let eq = equals {
                passed = actual == eq
                modeDesc = "== '\(eq)'"
            } else {
                passed = actual.localizedCaseInsensitiveContains(contains!)
                modeDesc = "contains '\(contains!)'"
            }
            let msg: String
            if passed {
                msg = "\(resolved.node.className)(oid:\(resolved.node.oid)) .\(key)='\(actual)' \(modeDesc) ✓"
            } else {
                msg = "\(resolved.node.className)(oid:\(resolved.node.oid)) .\(key)='\(actual)' does not match \(modeDesc)"
            }
            let result = AssertResult(passed: passed, assertion: "attr", locator: locator, matchCount: 1, message: msg)
            printAssertResult(result, mode: json ? .json : .human)
            if !passed { throw ExitCode(1) }
        } catch let error as LookinCoreError {
            if json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}
