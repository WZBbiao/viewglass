import Foundation
import Network

/// Low-level TCP connection to a LookinServer instance using NWConnection.
public final class LKTCPConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.lookin.tcp", qos: .userInitiated)
    private var buffer = Data()

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

    public func connect() async throws {
        state = .connecting
        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .connected
                    continuation.resume()
                case .failed(let error):
                    self.state = .failed(error)
                    continuation.resume(throwing: LookinCoreError.connectionFailed(host: self.host, port: self.port))
                case .cancelled:
                    self.state = .disconnected
                    continuation.resume(throwing: LookinCoreError.connectionFailed(host: self.host, port: self.port))
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    public func disconnect() {
        connection.cancel()
        state = .disconnected
    }

    /// Send a Peertalk frame and wait for the response frame.
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

        // Receive header
        let headerData = try await receive(exactLength: LKFrame.headerSize)
        guard let header = LKFrame.decodeHeader(headerData) else {
            throw LookinCoreError.protocolError(reason: "Invalid frame header")
        }

        // Receive payload
        var payloadData = Data()
        if header.payloadSize > 0 {
            payloadData = try await receive(exactLength: Int(header.payloadSize))
        }

        return LKFrame(type: header.type, tag: header.tag, payload: payloadData)
    }

    private func receive(exactLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: exactLength, maximumLength: exactLength) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: LookinCoreError.protocolError(reason: "No data received"))
                }
            }
        }
    }
}
