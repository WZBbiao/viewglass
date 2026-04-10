import Foundation

/// TCP-over-USB connection that owns a file descriptor obtained from LKUSBMuxdClient.
///
/// After `LKUSBMuxdClient.connectToDevice(deviceID:port:)` succeeds, the fd is a
/// transparent byte tunnel to the iOS device's port.  This class wraps that fd with
/// `DispatchIO` to provide truly async (non-blocking) I/O on an arbitrary POSIX fd –
/// the same pattern used by Peertalk/PTChannel in the macOS GUI app.
///
/// The interface mirrors LKTCPConnection so that LKProtocolClient can use either
/// transport transparently via LKConnectionProtocol.
public final class LKUSBMuxConnection: LKConnectionProtocol, @unchecked Sendable {

    private var fd: Int32
    private var io: DispatchIO?
    private let queue: DispatchQueue
    private var _connected = true

    /// Take ownership of `fd`.  The caller must not close the fd afterwards.
    public init(fd: Int32) {
        self.fd = fd
        self.queue = DispatchQueue(label: "viewglass.usb.io", qos: .userInitiated)
        // DispatchIO.stream: treat fd as a continuous byte stream.
        // The cleanup handler is called once when the channel is closed.
        let channel = DispatchIO(type: .stream, fileDescriptor: fd, queue: queue) { [fd] _ in
            // DispatchIO.close() already closed the fd; nothing more to do.
            _ = fd // capture to suppress warning
        }
        channel.setLimit(lowWater: 1)  // deliver data as soon as any arrives
        self.io = channel
    }

    deinit { disconnect() }

    // MARK: - LKConnectionProtocol

    public var isConnected: Bool { _connected }

    /// Disconnect gracefully: drain pending push bytes for 150 ms, then close.
    /// Same rationale as LKTCPConnection.disconnect() – avoiding RST keeps
    /// LookinServer's Peertalk healthy so other clients (the GUI) can still connect.
    public func disconnect() {
        guard _connected else { return }
        _connected = false
        guard let channel = io else { return }
        io = nil

        queue.async {
            let deadline = DispatchTime.now() + 0.15
            let sema = DispatchSemaphore(value: 0)
            func drainOne() {
                guard DispatchTime.now() < deadline else { sema.signal(); return }
                channel.read(offset: 0, length: 65_536, queue: self.queue) { done, data, _ in
                    if done { if data?.isEmpty ?? true { sema.signal() } else { drainOne() } }
                }
            }
            drainOne()
            sema.wait()
            channel.close(flags: .stop)
        }
    }

    public func sendRequest(type: UInt32, tag: UInt32, payload: Data = Data()) async throws -> LKFrame {
        let encoded = LKFrame(type: type, tag: tag, payload: payload).encode()
        try await writeAll(encoded)
        return try await receiveFrame()
    }

    public func receiveFrame() async throws -> LKFrame {
        let hdr = try await readExactly(LKFrame.headerSize)
        guard let h = LKFrame.decodeHeader(hdr) else {
            throw LookinCoreError.protocolError(reason: "USB: invalid Peertalk frame header")
        }
        let body = h.payloadSize > 0 ? try await readExactly(Int(h.payloadSize)) : Data()
        return LKFrame(type: h.type, tag: h.tag, payload: body)
    }

    public func drainPendingData(timeoutMs: Int32) async {
        guard let channel = io else { return }
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1_000)
        // 200 ms per-chunk watchdog prevents DispatchIO.read from blocking indefinitely
        // when no more push frames are coming but the connection stays open (real devices).
        while Date() < deadline {
            let chunkTimeout = min(deadline.timeIntervalSinceNow, 0.2)
            guard chunkTimeout > 0 else { break }
            let gotData = await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
                let once = LKOnce()
                queue.asyncAfter(deadline: .now() + chunkTimeout) {
                    guard once.fire() else { return }
                    k.resume(returning: false)
                }
                var accumulated = false
                channel.read(offset: 0, length: 65_536, queue: self.queue) { done, data, _ in
                    if let d = data, !d.isEmpty { accumulated = true }
                    if done {
                        guard once.fire() else { return }
                        k.resume(returning: accumulated)
                    }
                }
            }
            if !gotData { break }
        }
    }

    // MARK: - Private I/O helpers

    private func writeAll(_ data: Data) async throws {
        guard let channel = io else { throw LookinCoreError.sessionNotConnected }
        // DispatchData is reference-counted; bridging from Data is zero-copy.
        let dispatchData: DispatchData = data.withUnsafeBytes { DispatchData(bytes: $0) }
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            channel.write(offset: 0, data: dispatchData, queue: queue) { done, _, err in
                guard done else { return }
                if err != 0 {
                    k.resume(throwing: LookinCoreError.protocolError(
                        reason: "USB: write error \(err)"
                    ))
                } else {
                    k.resume()
                }
            }
        }
    }

    private func readExactly(_ count: Int, readTimeoutSeconds: TimeInterval = 5) async throws -> Data {
        guard io != nil else { throw LookinCoreError.sessionNotConnected }
        return try await withCheckedThrowingContinuation { k in
            let once = LKOnce()
            // Timeout watchdog – DispatchIO has no built-in read timeout.
            queue.asyncAfter(deadline: .now() + readTimeoutSeconds) {
                guard once.fire() else { return }
                k.resume(throwing: LookinCoreError.protocolError(
                    reason: "USB read timeout after \(readTimeoutSeconds)s"
                ))
            }
            accumulate(need: count, buffer: Data(), once: once, continuation: k)
        }
    }

    /// Recursive chunk accumulator.  DispatchIO calls its handler multiple times
    /// (once per chunk, once more with `done == true`); we collect everything until
    /// we have `need` bytes, then resume the continuation.
    private func accumulate(
        need: Int,
        buffer: Data,
        once: LKOnce,
        continuation: CheckedContinuation<Data, Error>
    ) {
        guard let channel = io else {
            guard once.fire() else { return }
            continuation.resume(throwing: LookinCoreError.sessionNotConnected)
            return
        }
        var accum = buffer
        channel.read(offset: 0, length: need - buffer.count, queue: queue) { done, data, err in
            if let d = data { accum.append(contentsOf: d) }
            guard done else { return }  // More chunks from this read; wait for done.
            if err != 0 {
                guard once.fire() else { return }
                continuation.resume(throwing: LookinCoreError.protocolError(
                    reason: "USB: read error \(err)"
                ))
            } else if accum.isEmpty {
                guard once.fire() else { return }
                continuation.resume(throwing: LookinCoreError.protocolError(
                    reason: "USB: connection closed before receiving \(need) bytes"
                ))
            } else if accum.count >= need {
                guard once.fire() else { return }
                continuation.resume(returning: accum)
            } else {
                // Got partial data; issue another read for the remainder.
                self.accumulate(need: need, buffer: accum, once: once, continuation: continuation)
            }
        }
    }
}
