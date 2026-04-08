import ArgumentParser
import LookinCore

struct SessionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "session",
        abstract: "Manage inspection sessions",
        subcommands: [SessionConnect.self, SessionStatus.self, SessionDisconnect.self]
    )
}

struct SessionConnect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Connect to an inspectable app"
    )

    @Argument(help: "App identifier (bundle ID or identifier@port)")
    var appId: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            let session = try await services.session.connect(appIdentifier: appId)
            OutputFormatter.printSession(session, mode: json ? .json : .human)
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

struct SessionStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current session status"
    )

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        if let session = await services.session.currentSession() {
            OutputFormatter.printSession(session, mode: json ? .json : .human)
        } else {
            let error = LookinCoreError.sessionNotConnected
            if json {
                JSONOutput.printError(error: error)
            } else {
                printStderr(error.localizedDescription)
            }
            throw ExitCode(error.exitCode)
        }
    }
}

struct SessionDisconnect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "disconnect",
        abstract: "Disconnect from current session"
    )

    @Option(name: .long, help: "Session ID")
    var session: String

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    mutating func run() async throws {
        let services = ServiceContainer.makeLive()
        do {
            try await services.session.disconnect(sessionId: session)
            if json {
                JSONOutput.printSuccess(message: "Disconnected from session \(session)")
            } else {
                print("Disconnected from session \(session)")
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
