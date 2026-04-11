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
                JSONOutput.print(FlatNodeAttributes.make(
                    oid: node.oid,
                    className: node.className,
                    groups: groups
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

/// AI-agent–friendly flat representation of a node's attributes.
/// Uses displayName as key and unwraps LKAttributeValue to native JSON types.
struct FlatNodeAttributes: Encodable {
    let oid: UInt
    let className: String
    let attributes: [String: FlatAttributeValue]

    static func make(oid: UInt, className: String, groups: [LKAttributeGroup]) -> FlatNodeAttributes {
        var dict: [String: FlatAttributeValue] = [:]
        for group in groups {
            for attr in group.attributes {
                // Prefer registry-mapped readable name over Lookin's obfuscated short identifier.
                let key = LKAttributeRegistry.readableName(forAttrIdentifier: attr.key)
                    ?? LKAttributeRegistry.readableName(forAttrIdentifier: attr.displayName)
                    ?? (attr.displayName.isEmpty ? attr.key : attr.displayName)
                dict[key] = FlatAttributeValue(attr.value)
            }
        }
        return FlatNodeAttributes(oid: oid, className: className, attributes: dict)
    }
}

enum FlatAttributeValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(_ value: LKAttributeValue) {
        switch value {
        case .string(let s): self = .string(s)
        case .number(let n): self = .number(n)
        case .bool(let b): self = .bool(b)
        case .rect(let r): self = .string("(\(r.x), \(r.y), \(r.width), \(r.height))")
        case .color(let c): self = .string(c)
        case .null: self = .null
        }
    }

    /// String representation for comparison (e.g. in `wait attr --equals`).
    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .number(let n):
            if n == n.rounded() && !n.isInfinite { return String(Int(n)) }
            return String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let n):
            if n == n.rounded() && !n.isInfinite { try container.encode(Int(n)) }
            else { try container.encode(n) }
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}

