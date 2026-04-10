import Foundation

/// Abstraction over the transport layer used by LKProtocolClient.
///
/// Two concrete implementations exist:
///   • LKTCPConnection  – NWConnection-based, used for simulator (127.0.0.1:47164-69)
///   • LKUSBMuxConnection – DispatchIO-based, wraps a file descriptor obtained from
///                          the usbmuxd Unix socket (replaces iproxy for real devices)
public protocol LKConnectionProtocol: AnyObject, Sendable {
    var isConnected: Bool { get }
    func disconnect()
    func sendRequest(type: UInt32, tag: UInt32, payload: Data) async throws -> LKFrame
    func receiveFrame() async throws -> LKFrame
    func drainPendingData(timeoutMs: Int32) async
}

// MARK: - Shared utilities

/// Thread-safe one-shot flag: used to guard continuations against being resumed twice
/// (e.g. by both a timeout watchdog and the real callback).
final class LKOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var _fired = false

    /// Returns `true` the first time it is called; `false` on every subsequent call.
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !_fired else { return false }
        _fired = true
        return true
    }
}
