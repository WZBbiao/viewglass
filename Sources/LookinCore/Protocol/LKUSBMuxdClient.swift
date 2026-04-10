import Foundation

/// Minimal Swift client for the macOS `usbmuxd` daemon.
///
/// `usbmuxd` is Apple's USB multiplexing daemon (at `/var/run/usbmuxd`).  Both
/// iproxy and Peertalk/PTUSBHub communicate with it under the hood; this class
/// does the same directly, removing the need for a separate iproxy process.
///
/// Protocol overview (plist variant, version 1):
///   Every message is a 16-byte header followed by an XML plist payload.
///   Header layout (all little-endian):
///     [0-3]  total length (including header)
///     [4-7]  version = 1
///     [8-11] message type = 8 (plist)
///     [12-15] tag (request ID)
///
/// The "Connect" message is the key operation: after a successful response the
/// underlying Unix socket becomes a transparent byte tunnel to the requested
/// TCP port on the iOS device.  The caller can then speak Peertalk/LookinServer
/// protocol directly over that fd without any local TCP proxy.
///
/// Reference: https://github.com/libimobiledevice/libusbmuxd
public final class LKUSBMuxdClient {

    public struct Device: Sendable {
        public let deviceID: Int
        public let udid: String
    }

    private static let socketPath = "/var/run/usbmuxd"
    private var fd: Int32 = -1
    private var tagCounter: UInt32 = 0

    public init() {}

    deinit { closeSocket() }

    // MARK: - Public API

    /// Connect to the usbmuxd Unix socket.  Must be called before any other method.
    public func open() throws {
        let s = socket(AF_UNIX, SOCK_STREAM, 0)
        guard s >= 0 else {
            throw LookinCoreError.protocolError(
                reason: "usbmuxd: socket() failed – \(errnoString())"
            )
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = Self.socketPath
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < maxLen else {
            close(s)
            throw LookinCoreError.protocolError(reason: "usbmuxd: socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { dst in
            path.withCString { src in
                dst.withMemoryRebound(to: CChar.self, capacity: maxLen) {
                    _ = strcpy($0, src)
                }
            }
        }

        let rc = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if rc < 0 {
            close(s)
            throw LookinCoreError.protocolError(
                reason: "usbmuxd: connect(\(path)) failed – \(errnoString())"
            )
        }
        // 3-second read timeout – prevents blocking the caller indefinitely
        // if usbmuxd is slow or the device is unresponsive.
        var tv = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        fd = s
    }

    /// Return all currently attached USB devices.
    public func listDevices() throws -> [Device] {
        let tag = nextTag()
        try sendPlist([
            "MessageType": "ListDevices",
            "ClientVersionString": "viewglass",
            "ProgName": "viewglass",
        ], tag: tag)
        let reply = try recvPlist()
        guard let list = reply["DeviceList"] as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard
                let props = entry["Properties"] as? [String: Any],
                let id    = props["DeviceID"] as? Int,
                let udid  = props["SerialNumber"] as? String
            else { return nil }
            return Device(deviceID: id, udid: udid)
        }
    }

    /// Establish a connection to `port` on device `deviceID`.
    ///
    /// On success the underlying Unix socket fd is promoted to a transparent tunnel
    /// to the device's TCP port.  Returns that fd; the caller takes ownership and
    /// this object must not be used afterwards (it has transferred the fd).
    public func connectToDevice(deviceID: Int, port: UInt16) throws -> Int32 {
        // usbmuxd expects the port in network byte order (big-endian) as a plain integer
        let networkPort = Int(port.bigEndian)
        let tag = nextTag()
        try sendPlist([
            "MessageType":       "Connect",
            "ClientVersionString": "viewglass",
            "ProgName":          "viewglass",
            "DeviceID":          deviceID,
            "PortNumber":        networkPort,
        ], tag: tag)
        let reply = try recvPlist()
        guard let code = reply["Number"] as? Int, code == 0 else {
            let code = reply["Number"] as? Int ?? -1
            throw LookinCoreError.protocolError(
                reason: "usbmuxd: Connect refused (code \(code)). " +
                        "Ensure the app is running in the foreground."
            )
        }
        // Transfer ownership of the fd to the caller.
        let connected = fd
        fd = -1
        return connected
    }

    // MARK: - Private

    private func nextTag() -> UInt32 {
        tagCounter += 1
        return tagCounter
    }

    private func sendPlist(_ dict: [String: Any], tag: UInt32) throws {
        let plistData: Data
        do {
            plistData = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .xml,
                options: 0
            )
        } catch {
            throw LookinCoreError.protocolError(
                reason: "usbmuxd: plist serialisation failed – \(error)"
            )
        }
        let total = UInt32(16 + plistData.count).littleEndian
        let ver:  UInt32 = UInt32(1).littleEndian
        let typ:  UInt32 = UInt32(8).littleEndian   // plist message type
        let tagLE: UInt32 = tag.littleEndian
        var hdr = Data(count: 16)
        withUnsafeBytes(of: total)  { bytes in hdr.replaceSubrange(0..<4,  with: bytes) }
        withUnsafeBytes(of: ver)    { bytes in hdr.replaceSubrange(4..<8,  with: bytes) }
        withUnsafeBytes(of: typ)    { bytes in hdr.replaceSubrange(8..<12, with: bytes) }
        withUnsafeBytes(of: tagLE)  { bytes in hdr.replaceSubrange(12..<16,with: bytes) }
        try sendAll(hdr + plistData)
    }

    private func recvPlist() throws -> [String: Any] {
        let hdr = try recvAll(16)
        let totalLen = hdr.subdata(in: 0..<4)
            .withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        let payloadLen = Int(totalLen) - 16
        guard payloadLen >= 0 else {
            throw LookinCoreError.protocolError(reason: "usbmuxd: invalid response length")
        }
        if payloadLen == 0 { return [:] }
        let payload = try recvAll(payloadLen)
        guard
            let plist = try? PropertyListSerialization.propertyList(from: payload, format: nil),
            let dict  = plist as? [String: Any]
        else {
            throw LookinCoreError.protocolError(reason: "usbmuxd: cannot parse plist response")
        }
        return dict
    }

    private func sendAll(_ data: Data) throws {
        var sent = 0
        let total = data.count
        try data.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            while sent < total {
                let n = Darwin.send(fd, base.advanced(by: sent), total - sent, 0)
                guard n > 0 else {
                    throw LookinCoreError.protocolError(
                        reason: "usbmuxd: send() failed – \(errnoString())"
                    )
                }
                sent += n
            }
        }
    }

    private func recvAll(_ count: Int) throws -> Data {
        var buf = Data(count: count)
        var received = 0
        try buf.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            while received < count {
                let n = Darwin.recv(fd, base.advanced(by: received), count - received, 0)
                guard n > 0 else {
                    throw LookinCoreError.protocolError(
                        reason: "usbmuxd: recv() failed (\(n)) – \(errnoString())"
                    )
                }
                received += n
            }
        }
        return buf
    }

    private func closeSocket() {
        if fd >= 0 { close(fd); fd = -1 }
    }

    private func errnoString() -> String {
        String(cString: strerror(errno))
    }
}
