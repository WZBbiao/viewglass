import Foundation

/// Peertalk frame header: 16 bytes
/// - version: UInt32 (always 1)
/// - type: UInt32 (message type)
/// - tag: UInt32 (request ID)
/// - payloadSize: UInt32 (payload length)
public struct LKFrame {
    public static let headerSize = 16
    public static let protocolVersion: UInt32 = 1

    public let type: UInt32
    public let tag: UInt32
    public let payload: Data

    public init(type: UInt32, tag: UInt32, payload: Data = Data()) {
        self.type = type
        self.tag = tag
        self.payload = payload
    }

    public func encode() -> Data {
        var data = Data(capacity: Self.headerSize + payload.count)
        var version = Self.protocolVersion.bigEndian
        var type = self.type.bigEndian
        var tag = self.tag.bigEndian
        var size = UInt32(payload.count).bigEndian
        data.append(Data(bytes: &version, count: 4))
        data.append(Data(bytes: &type, count: 4))
        data.append(Data(bytes: &tag, count: 4))
        data.append(Data(bytes: &size, count: 4))
        data.append(payload)
        return data
    }

    public static func decodeHeader(_ data: Data) -> (version: UInt32, type: UInt32, tag: UInt32, payloadSize: UInt32)? {
        guard data.count >= headerSize else { return nil }
        let version = data.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let type = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let tag = data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let payloadSize = data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        return (version, type, tag, payloadSize)
    }
}
