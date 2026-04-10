import Foundation
import Network

/// Low-level TCP connection using NWConnection for truly async (non-blocking) I/O.
///
/// Replaces the previous BSD-socket implementation that called blocking `recv()` inside
/// Swift async functions, which stalled cooperative thread-pool threads and caused
/// cascading latency across the entire command.
///
/// Key design decisions:
/// - All I/O is dispatched on `ioQueue`; Swift concurrency continuations bridge results back.
/// - `receiveExactly(_:)` accumulates chunks recursively until the required byte count is
///   reached, matching the Peertalk frame protocol without over-reading.
/// - `drainPendingData(timeoutMs:)` is `async` so the caller never blocks a thread.
/// - Explicit `cancel()` in `disconnect()` sends FIN (not RST) as long as the receive
///   buffer has been drained beforehand by `drainPendingData`.
public final class LKTCPConnection: @unchecked Sendable {

    public let host: String
    public let port: Int

    public enum State: Sendable {
        case idle
        case connecting
        case connected
        case disconnected
        case failed(Error)
    }

    public private(set) var state: State = .idle

    private var nwConn: NWConnection?
    private let ioQueue = DispatchQueue(label: "viewglass.lktcp.io", qos: .userInitiated)

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    deinit {
        nwConn?.cancel()
    }

    // MARK: - Connect / Disconnect

    public func connect(timeout: TimeInterval = 0.5) async throws {
        state = .connecting

        let c = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = Once()

            c.stateUpdateHandler = { [weak self] newState in
                switch newState {
                case .ready:
                    guard once.fire() else { return }
                    self?.state = .connected
                    cont.resume()
                case .failed(let err):
                    guard once.fire() else { return }
                    self?.state = .failed(err)
                    c.cancel()
                    cont.resume(throwing: LookinCoreError.protocolError(
                        reason: "Connect failed: \(err.localizedDescription)"
                    ))
                case .cancelled:
                    guard once.fire() else { return }
                    cont.resume(throwing: LookinCoreError.connectionTimeout)
                default:
                    break
                }
            }

            c.start(queue: ioQueue)

            // Timeout watchdog – fires on ioQueue to stay serialised with state handler.
            ioQueue.asyncAfter(deadline: .now() + timeout) {
                guard once.fire() else { return }
                c.cancel()
                cont.resume(throwing: LookinCoreError.connectionTimeout)
            }
        }

        nwConn = c
    }

    public func disconnect() {
        nwConn?.cancel()
        nwConn = nil
        state = .disconnected
    }

    public var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    // MARK: - Frame I/O

    /// Send a Peertalk request frame and receive the single response frame.
    public func sendRequest(type: UInt32, tag: UInt32, payload: Data = Data()) async throws -> LKFrame {
        let encoded = LKFrame(type: type, tag: tag, payload: payload).encode()
        try await sendAll(encoded)
        return try await receiveFrame()
    }

    /// Receive a single Peertalk frame (for multi-frame responses).
    public func receiveFrame() async throws -> LKFrame {
        let hdr = try await receiveExactly(LKFrame.headerSize)
        guard let h = LKFrame.decodeHeader(hdr) else {
            throw LookinCoreError.protocolError(reason: "Invalid frame header")
        }
        let body = h.payloadSize > 0
            ? try await receiveExactly(Int(h.payloadSize))
            : Data()
        return LKFrame(type: h.type, tag: h.tag, payload: body)
    }

    /// Drain server-push frames for up to `timeoutMs` milliseconds.
    ///
    /// After a mutation LookinServer broadcasts display-update push frames.  If we close
    /// the socket while those bytes are still in the TCP receive buffer, the OS will
    /// send RST instead of FIN, which causes LookinServer's Peertalk to enter an error
    /// state and stop accepting new connections.  Draining before `disconnect()` keeps
    /// the server healthy.
    public func drainPendingData(timeoutMs: Int32) async {
        guard let c = nwConn else { return }
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1_000)
        while Date() < deadline {
            let gotData = await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
                c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, _ in
                    k.resume(returning: !(data?.isEmpty ?? true))
                }
            }
            if !gotData { break }
        }
    }

    // MARK: - Private helpers

    private func sendAll(_ data: Data) async throws {
        guard let c = nwConn else { throw LookinCoreError.sessionNotConnected }
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            c.send(content: data, completion: .contentProcessed { err in
                if let err = err {
                    k.resume(throwing: LookinCoreError.protocolError(
                        reason: "Send failed: \(err.localizedDescription)"
                    ))
                } else {
                    k.resume()
                }
            })
        }
    }

    /// Read exactly `count` bytes, accumulating chunks as they arrive.
    private func receiveExactly(_ count: Int) async throws -> Data {
        guard count > 0 else { return Data() }
        guard let c = nwConn else { throw LookinCoreError.sessionNotConnected }
        return try await withCheckedThrowingContinuation { k in
            accumulate(conn: c, need: count, buffer: Data(), continuation: k)
        }
    }

    /// Recursive accumulator – called on `ioQueue` via NWConnection callbacks.
    private func accumulate(
        conn: NWConnection,
        need: Int,
        buffer: Data,
        continuation: CheckedContinuation<Data, Error>
    ) {
        let remaining = need - buffer.count
        conn.receive(minimumIncompleteLength: 1, maximumLength: remaining) { data, _, isDone, err in
            if let err = err {
                continuation.resume(throwing: LookinCoreError.protocolError(
                    reason: err.localizedDescription
                ))
                return
            }
            var next = buffer
            if let d = data { next.append(contentsOf: d) }

            if next.count >= need {
                continuation.resume(returning: next)
            } else if isDone {
                continuation.resume(throwing: LookinCoreError.protocolError(
                    reason: "Connection closed (\(next.count)/\(need) bytes received)"
                ))
            } else {
                self.accumulate(conn: conn, need: need, buffer: next, continuation: continuation)
            }
        }
    }
}

// MARK: - Once

/// Thread-safe one-shot flag used to guard continuations from being resumed twice.
private final class Once: @unchecked Sendable {
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
