import Foundation

public protocol SessionServiceProtocol: Sendable {
    func discoverApps() async throws -> [LKAppDescriptor]
    func connect(appIdentifier: String) async throws -> LKSessionDescriptor
    func disconnect(sessionId: String) async throws
    func currentSession() async -> LKSessionDescriptor?
}
