import Foundation

/// Persists session state to disk so CLI invocations can share a session.
/// Storage path: ~/.lookin-cli/session.json
public final class SessionStore: @unchecked Sendable {
    private let directoryURL: URL
    private let fileURL: URL

    public init(directory: String = "~/.lookin-cli") {
        let expanded = NSString(string: directory).expandingTildeInPath
        self.directoryURL = URL(fileURLWithPath: expanded, isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent("session.json")
    }

    public func save(_ session: LKSessionDescriptor) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() -> LKSessionDescriptor? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LKSessionDescriptor.self, from: data)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
