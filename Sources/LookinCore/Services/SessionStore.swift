import Foundation

/// Persists session state to disk so CLI invocations can share a session.
/// Storage path: ~/.viewglass/session.json
public final class SessionStore: @unchecked Sendable {
    private let directoryURL: URL
    private let fileURL: URL
    private let legacyFileURL: URL

    public init(directory: String = "~/.viewglass") {
        let expanded = NSString(string: directory).expandingTildeInPath
        self.directoryURL = URL(fileURLWithPath: expanded, isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent("session.json")
        let legacyDirectory = NSString(string: "~/.lookin-cli").expandingTildeInPath
        self.legacyFileURL = URL(fileURLWithPath: legacyDirectory, isDirectory: true)
            .appendingPathComponent("session.json")
    }

    public func save(_ session: LKSessionDescriptor) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
        if FileManager.default.fileExists(atPath: legacyFileURL.path) {
            try? FileManager.default.removeItem(at: legacyFileURL)
        }
    }

    public func load() -> LKSessionDescriptor? {
        let sourceURL: URL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            sourceURL = fileURL
        } else if FileManager.default.fileExists(atPath: legacyFileURL.path) {
            sourceURL = legacyFileURL
        } else {
            return nil
        }
        guard let data = try? Data(contentsOf: sourceURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LKSessionDescriptor.self, from: data)
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        if FileManager.default.fileExists(atPath: legacyFileURL.path) {
            try FileManager.default.removeItem(at: legacyFileURL)
        }
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path) ||
            FileManager.default.fileExists(atPath: legacyFileURL.path)
    }
}
