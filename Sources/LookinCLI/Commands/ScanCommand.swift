import ArgumentParser
import LookinCore

struct ScanCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan for inspectable apps on all Lookin ports (live test)"
    )

    mutating func run() async throws {
        await LKQuickTest.scanAndReport()
    }
}
