import ArgumentParser
import CoreGraphics
import LookinCore

struct SwipeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Swipe a UIScrollView node in a given direction"
    )

    @Argument(help: "Target locator, OID, or resolved-target JSON")
    var target: String

    @Option(name: .long, help: "Swipe direction: up, down, left, right")
    var direction: String

    @Option(name: .long, help: "Distance to swipe in points (default: 200)")
    var distance: Double = 200.0

    @Flag(name: .long, help: "Animate the swipe with ease-in-out interpolation")
    var animated = false

    @Option(name: .long, help: "Session ID (auto-detected if omitted)")
    var session: String?

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        guard let dir = LKSwipeDirection(rawValue: direction.lowercased()) else {
            let valid = LKSwipeDirection.allCases.map(\.rawValue).joined(separator: ", ")
            throw ValidationError("Invalid direction '\(direction)'. Valid values: \(valid).")
        }
        let services = ServiceContainer.makeLive()
        defer { services.shutdown() }
        do {
            let sessionId = try resolveSession(session, services: services)
            let resolved = try await resolveActionTarget(
                target,
                services: services,
                sessionId: sessionId,
                action: "swipe"
            )
            let result = try await services.mutation.triggerSwipe(
                nodeOid: resolved.targets.actionOid,
                direction: dir,
                distance: CGFloat(distance),
                animated: animated,
                sessionId: sessionId
            )
            OutputFormatter.printAction(result, mode: json ? .json : .human)
        } catch let error as LookinCoreError {
            if json { JSONOutput.printError(error: error) } else { printStderr(error.localizedDescription) }
            throw ExitCode(error.exitCode)
        }
    }
}
