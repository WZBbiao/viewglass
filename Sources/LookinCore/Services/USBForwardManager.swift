import Foundation
import Network

public struct LKUSBForwardRecord: Codable, Equatable, Sendable {
    public let deviceIdentifier: String
    public let remotePort: Int
    public let localPort: Int
    public let pid: Int32
}

public final class USBForwardManager: @unchecked Sendable {
    private let recordsURL: URL
    private let fm = FileManager.default
    private let iproxyPath: String?

    public init(directory: String = "~/.viewglass") {
        let expanded = NSString(string: directory).expandingTildeInPath
        let dirURL = URL(fileURLWithPath: expanded, isDirectory: true)
        self.recordsURL = dirURL.appendingPathComponent("usb-forwards.json")
        self.iproxyPath = USBForwardManager.resolveExecutablePath(candidates: [
            "/opt/homebrew/bin/iproxy",
            "/usr/local/bin/iproxy"
        ], command: "iproxy")
    }

    public func connectedDeviceIdentifiers() -> [String] {
        guard let output = try? run(["idevice_id", "-l"]) else { return [] }
        return output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func ensureForward(deviceIdentifier: String, remotePort: Int, preferredLocalPort: Int? = nil) throws -> Int {
        cleanupStaleRecords()
        var records = loadRecords()
        if let existing = records.first(where: { $0.deviceIdentifier == deviceIdentifier && $0.remotePort == remotePort }),
           isProcessAlive(existing.pid),
           isPortReachable(existing.localPort) {
            return existing.localPort
        }

        let localPort = preferredLocalPort ?? suggestedLocalPort(deviceIdentifier: deviceIdentifier, remotePort: remotePort)
        let pid = try startIProxy(deviceIdentifier: deviceIdentifier, localPort: localPort, remotePort: remotePort)
        let record = LKUSBForwardRecord(
            deviceIdentifier: deviceIdentifier,
            remotePort: remotePort,
            localPort: localPort,
            pid: pid
        )
        records.removeAll { $0.deviceIdentifier == deviceIdentifier && $0.remotePort == remotePort }
        records.append(record)
        try saveRecords(records)
        return localPort
    }

    public func stopForward(deviceIdentifier: String?, remotePort: Int?, localPort: Int?) {
        var records = loadRecords()
        let matches = records.filter { record in
            let deviceOK = deviceIdentifier == nil || record.deviceIdentifier == deviceIdentifier
            let remoteOK = remotePort == nil || record.remotePort == remotePort
            let localOK = localPort == nil || record.localPort == localPort
            return deviceOK && remoteOK && localOK
        }
        for record in matches {
            _ = try? run(["kill", "\(record.pid)"])
        }
        records.removeAll { record in
            matches.contains(record)
        }
        try? saveRecords(records)
    }

    public func cleanupStaleRecords() {
        let live = loadRecords().filter { isProcessAlive($0.pid) }
        try? saveRecords(live)
    }

    public func startTemporaryForward(deviceIdentifier: String, remotePort: Int, preferredLocalPort: Int? = nil) throws -> LKUSBForwardRecord {
        cleanupStaleRecords()
        let localPort = preferredLocalPort ?? suggestedLocalPort(deviceIdentifier: deviceIdentifier, remotePort: remotePort)
        let pid = try startIProxy(deviceIdentifier: deviceIdentifier, localPort: localPort, remotePort: remotePort)
        return LKUSBForwardRecord(
            deviceIdentifier: deviceIdentifier,
            remotePort: remotePort,
            localPort: localPort,
            pid: pid
        )
    }

    public func stopForward(_ record: LKUSBForwardRecord) {
        _ = try? run(["kill", "\(record.pid)"])
        stopForward(deviceIdentifier: record.deviceIdentifier, remotePort: record.remotePort, localPort: record.localPort)
    }

    public func suggestedLocalPort(deviceIdentifier: String, remotePort: Int) -> Int {
        let hash = stableHash(deviceIdentifier) % 1000
        return 52000 + (hash * 10) + (remotePort - 47175)
    }

    private func startIProxy(deviceIdentifier: String, localPort: Int, remotePort: Int) throws -> Int32 {
        guard let iproxyPath else {
            throw LookinCoreError.protocolError(reason: "iproxy is required for USB device support but was not found in PATH")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: iproxyPath)
        process.arguments = ["\(localPort)", "\(remotePort)", "-u", deviceIdentifier]

        let devNull = FileHandle(forWritingAtPath: "/dev/null")
        process.standardOutput = devNull
        process.standardError = devNull
        process.standardInput = nil

        try process.run()
        let pid = process.processIdentifier

        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if isPortReachable(localPort) {
                return pid
            }
            usleep(100_000)
        }

        process.terminate()
        throw LookinCoreError.connectionFailed(host: "127.0.0.1", port: localPort)
    }

    private func isPortReachable(_ port: Int) -> Bool {
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)), using: .tcp)
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                reachable = true
                connection.cancel()
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: .global())
        _ = semaphore.wait(timeout: .now() + 0.2)
        return reachable
    }

    private func isProcessAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }

    private func loadRecords() -> [LKUSBForwardRecord] {
        guard let data = try? Data(contentsOf: recordsURL) else { return [] }
        return (try? JSONDecoder().decode([LKUSBForwardRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [LKUSBForwardRecord]) throws {
        try fm.createDirectory(at: recordsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        try data.write(to: recordsURL, options: .atomic)
    }

    @discardableResult
    private func run(_ command: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw LookinCoreError.protocolError(reason: "Command failed: \(command.joined(separator: " "))")
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func stableHash(_ string: String) -> Int {
        string.utf8.reduce(5381) { partial, byte in
            ((partial << 5) &+ partial) &+ Int(byte)
        }
    }

    private static func resolveExecutablePath(candidates: [String], command: String) -> String? {
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }
}
