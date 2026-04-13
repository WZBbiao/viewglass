import Foundation

/// Low-level TCP connection using BSD sockets for reliable close behavior.
/// NWConnection's process-exit cleanup sends RST instead of FIN, which causes
/// LookinServer's Peertalk to enter error state and stop re-listening.
public final class LKTCPConnection: @unchecked Sendable {
    private var socketFD: Int32 = -1
    private let lock = NSLock()

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
    private var recvBuffer = Data()

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    deinit {
        if socketFD >= 0 {
            close(socketFD)
        }
    }

    public func connect(timeout: TimeInterval = 0.5) async throws {
        state = .connecting

        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            state = .failed(LookinCoreError.connectionFailed(host: host, port: port))
            throw LookinCoreError.connectionFailed(host: host, port: port)
        }

        // Set non-blocking for timeout support
        var flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        let ipConversionResult = host.withCString { cString in
            inet_pton(AF_INET, cString, &addr.sin_addr)
        }
        guard ipConversionResult == 1 else {
            close(socketFD)
            socketFD = -1
            state = .failed(LookinCoreError.connectionFailed(host: host, port: port))
            throw LookinCoreError.connectionFailed(host: host, port: port)
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult < 0 && errno != EINPROGRESS {
            close(socketFD)
            socketFD = -1
            let error = LookinCoreError.protocolError(reason: "Connect failed: \(String(cString: strerror(errno)))")
            state = .failed(error)
            throw error
        }

        // Wait for connection with timeout using poll() to avoid fd_set packing issues.
        var pollDescriptor = pollfd(fd: socketFD, events: Int16(POLLOUT), revents: 0)
        let pollTimeout = Int32(timeout * 1000)
        let pollResult = Darwin.poll(&pollDescriptor, 1, pollTimeout)

        if pollResult <= 0 {
            close(socketFD)
            socketFD = -1
            state = .failed(LookinCoreError.connectionTimeout)
            throw LookinCoreError.connectionTimeout
        }

        // Check for connection error
        var error: Int32 = 0
        var errorLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &error, &errorLen)
        if error != 0 {
            close(socketFD)
            socketFD = -1
            let connectionError = LookinCoreError.protocolError(reason: "Connect failed: \(String(cString: strerror(error)))")
            state = .failed(connectionError)
            throw connectionError
        }

        // Set back to blocking mode
        flags = fcntl(socketFD, F_GETFL, 0)
        _ = fcntl(socketFD, F_SETFL, flags & ~O_NONBLOCK)

        // Set read timeout
        var readTimeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))

        state = .connected
    }

    public func disconnect() {
        guard socketFD >= 0 else { return }

        // Drain any pending data the server may have sent (push messages).
        // Without draining, the server's write will fail when we close,
        // causing Peertalk to enter error state and stop re-listening.
        var drainTimeout = timeval(tv_sec: 0, tv_usec: 100_000) // 100ms
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &drainTimeout, socklen_t(MemoryLayout<timeval>.size))
        var drainBuf = [UInt8](repeating: 0, count: 65536)
        while recv(socketFD, &drainBuf, drainBuf.count, 0) > 0 {}

        // Graceful shutdown — sends FIN, waits for server ACK
        shutdown(socketFD, SHUT_WR)
        // Read until server closes its end
        while recv(socketFD, &drainBuf, drainBuf.count, 0) > 0 {}

        close(socketFD)
        socketFD = -1
        state = .disconnected
    }

    /// Send a Peertalk frame and receive the complete response frame.
    public func sendRequest(type: UInt32, tag: UInt32, payload: Data = Data()) async throws -> LKFrame {
        let frame = LKFrame(type: type, tag: tag, payload: payload)
        let encoded = frame.encode()

        // Send
        try sendAll(encoded)

        // Receive response frame
        return try readFrame()
    }

    /// Receive a single frame (for multi-frame responses).
    public func receiveFrame() async throws -> LKFrame {
        try readFrame()
    }

    /// Drain any pending data from the server using a short timeout.
    /// This prevents server-side errors when the connection is closed
    /// while the server still has data to send.
    public func drainPendingData(timeoutMs: Int32) {
        guard socketFD >= 0 else { return }
        var drainTimeout = timeval(tv_sec: 0, tv_usec: timeoutMs * 1000)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &drainTimeout, socklen_t(MemoryLayout<timeval>.size))
        var buf = [UInt8](repeating: 0, count: 65536)
        while recv(socketFD, &buf, buf.count, 0) > 0 {}
        // Restore normal timeout
        var normalTimeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &normalTimeout, socklen_t(MemoryLayout<timeval>.size))
        // Clear the receive buffer
        recvBuffer = Data()
    }

    // MARK: - Raw socket I/O

    private func sendAll(_ data: Data) throws {
        guard socketFD >= 0 else { throw LookinCoreError.sessionNotConnected }
        var sent = 0
        let total = data.count
        try data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return }
            while sent < total {
                let n = send(socketFD, ptr.advanced(by: sent), total - sent, 0)
                if n < 0 {
                    throw LookinCoreError.protocolError(reason: "Send failed: \(String(cString: strerror(errno)))")
                }
                sent += n
            }
        }
    }

    private func readFrame() throws -> LKFrame {
        // Read header
        while recvBuffer.count < LKFrame.headerSize {
            try readChunk()
        }

        guard let header = LKFrame.decodeHeader(recvBuffer) else {
            throw LookinCoreError.protocolError(reason: "Invalid frame header")
        }

        let totalNeeded = LKFrame.headerSize + Int(header.payloadSize)

        // Read payload
        while recvBuffer.count < totalNeeded {
            try readChunk()
        }

        let payloadData = recvBuffer.subdata(in: LKFrame.headerSize..<totalNeeded)
        recvBuffer = recvBuffer.subdata(in: totalNeeded..<recvBuffer.count)

        return LKFrame(type: header.type, tag: header.tag, payload: payloadData)
    }

    private func readChunk() throws {
        guard socketFD >= 0 else { throw LookinCoreError.protocolError(reason: "Connection closed") }
        var buffer = [UInt8](repeating: 0, count: 65536)
        let n = recv(socketFD, &buffer, buffer.count, 0)
        if n <= 0 {
            throw LookinCoreError.protocolError(reason: "Connection closed")
        }
        recvBuffer.append(buffer, count: n)
    }
}
