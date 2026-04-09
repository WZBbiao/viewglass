import ArgumentParser
import LookinCore

struct AttrCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "attr",
        abstract: "Get or set node attributes",
        subcommands: [AttrGet.self, AttrSet.self]
    )
}

struct AttrGet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get all attributes of a node"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

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
                target,
                services: services,
                sessionId: sessionId,
                action: "attr-get",
                capability: "inspect"
            )
            let node = resolved.node
            let groups = try await services.nodeQuery.getAttributes(oid: resolved.targets.inspectOid, sessionId: sessionId)
            if json {
                JSONOutput.print(NodeAttributes(
                    oid: node.oid,
                    className: node.className,
                    attributes: groups
                ))
            } else {
                print("\(node.className) (oid:\(node.oid))")
                if !groups.isEmpty {
                    for group in groups {
                        print("  [\(group.groupName)]")
                        for attr in group.attributes {
                            let readonly = attr.isReadonly ? " (readonly)" : ""
                            print("    \(attr.displayName): \(attr.value.stringValue)\(readonly)")
                        }
                    }
                } else {
                    print("  No attribute data available. Try refreshing the hierarchy first.")
                }
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

struct AttrSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set an attribute on a node"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Argument(help: "Attribute key (e.g. 'frame.origin.x', 'alpha', 'hidden')")
    var key: String

    @Argument(help: "New value")
    var value: String

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Force dangerous mutations")
    var force = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()

        let dangerousKeys = ["removeFromSuperview", "dealloc", "release"]
        if dangerousKeys.contains(key) && !force {
            let msg = "Refusing dangerous mutation '\(key)'. Use --force to override."
            if json {
                JSONOutput.printError(message: msg, code: 50)
            } else {
                printStderr(msg)
            }
            throw ExitCode(50)
        }

        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                target,
                services: services,
                sessionId: sessionId,
                action: "attr-set"
            )
            let result = try await services.mutation.setAttribute(
                nodeOid: resolved.targets.actionOid,
                key: key,
                value: value,
                sessionId: sessionId
            )
            OutputFormatter.printModification(result, mode: json ? .json : .human)
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

struct NodeAttributes: Codable {
    let oid: UInt
    let className: String
    let attributes: [LKAttributeGroup]
}
