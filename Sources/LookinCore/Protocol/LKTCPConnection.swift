import Foundation
import Network

/// Low-level TCP connection to a LookinServer instance using NWConnection.
public final class LKTCPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.lookin.tcp", qos: .userInitiated)
    private var recvBuffer = Data()

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

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: .tcp
        )
    }

    public func connect(timeout: TimeInterval = 0.5) async throws {
        state = .connecting
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            let resumeOnce: (Result<Void, Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success: continuation.resume()
                case .failure(let e): continuation.resume(throwing: e)
                }
            }

            // Timeout — only cancel if we haven't connected yet
            self.queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                guard !resumed else { return } // Already connected, don't cancel
                resumeOnce(.failure(LookinCoreError.connectionTimeout))
                self.connection.cancel()
            }

            self.connection.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .connected
                    self.connection.stateUpdateHandler = { [weak self] state in
                        if case .cancelled = state { self?.state = .disconnected }
                        if case .failed = state { self?.state = .disconnected }
                    }
                    resumeOnce(.success(()))
                case .failed:
                    self.state = .disconnected
                    resumeOnce(.failure(LookinCoreError.connectionFailed(host: self.host, port: self.port)))
                case .cancelled:
                    self.state = .disconnected
                    resumeOnce(.failure(LookinCoreError.connectionFailed(host: self.host, port: self.port)))
                default:
                    break
                }
            }
            self.connection.start(queue: self.queue)
        }
    }

    public func disconnect() {
        connection.cancel()
        state = .disconnected
    }

    /// Send a Peertalk frame and receive the complete response frame.
    public func sendRequest(type: UInt32, tag: UInt32, payload: Data = Data()) async throws -> LKFrame {
        let frame = LKFrame(type: type, tag: tag, payload: payload)
        let encoded = frame.encode()

        // Send
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: encoded, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // Receive full response: header + payload
        // NWConnection may deliver header+payload together or separately
        // We need to accumulate until we have the complete frame

        // Step 1: Ensure we have at least the header (16 bytes)
        while recvBuffer.count < LKFrame.headerSize {
            let chunk = try await receiveChunk()
            recvBuffer.append(chunk)
        }

        // Step 2: Parse header to get payload size
        guard let header = LKFrame.decodeHeader(recvBuffer) else {
            throw LookinCoreError.protocolError(reason: "Invalid frame header")
        }

        let totalNeeded = LKFrame.headerSize + Int(header.payloadSize)

        // Step 3: Ensure we have the complete frame
        while recvBuffer.count < totalNeeded {
            let chunk = try await receiveChunk()
            recvBuffer.append(chunk)
        }

        // Step 4: Extract the frame and leave remainder in buffer
        let payloadData = recvBuffer.subdata(in: LKFrame.headerSize..<totalNeeded)
        recvBuffer = recvBuffer.subdata(in: totalNeeded..<recvBuffer.count)

        return LKFrame(type: header.type, tag: header.tag, payload: payloadData)
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: LookinCoreError.protocolError(reason: "Connection closed"))
                }
            }
        }
    }
}
