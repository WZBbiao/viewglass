import Foundation
import LookinSharedBridge

/// High-level protocol client that handles serialization and request lifecycle.
public final class LKProtocolClient: @unchecked Sendable {
    private var connection: LKTCPConnection?
    private var tagCounter: UInt32 = 1

    public init() {}

    /// Try to connect to a LookinServer on a specific port.
    public func connect(host: String = "127.0.0.1", port: Int) async throws {
        let conn = LKTCPConnection(host: host, port: port)
        try await conn.connect()
        self.connection = conn

        // Send ping to verify connection
        try await ping()
    }

    public func disconnect() {
        connection?.disconnect()
        connection = nil
    }

    public var isConnected: Bool {
        if case .connected = connection?.state { return true }
        return false
    }

    private func nextTag() -> UInt32 {
        tagCounter += 1
        return tagCounter
    }

    // MARK: - Requests

    /// Ping the server to check connectivity and version.
    public func ping() async throws {
        let response = try await sendRequest(type: LookinRequestTypePing, data: nil)
        if response.appIsInBackground {
            throw LookinCoreError.appInBackground
        }
        let serverVersion = response.lookinServerVersion
        if serverVersion < LOOKIN_SUPPORTED_SERVER_MIN || serverVersion > LOOKIN_SUPPORTED_SERVER_MAX {
            throw LookinCoreError.serverVersionMismatch(
                server: "\(serverVersion)",
                client: "\(LOOKIN_CLIENT_VERSION)"
            )
        }
    }

    /// Discover the app running on the connected port.
    public func fetchAppInfo(needImages: Bool = false) async throws -> LookinAppInfo {
        let requestData: NSDictionary = [
            "needImages": NSNumber(value: needImages),
            "local": NSArray()
        ]
        let response = try await sendRequest(type: LookinRequestTypeApp, data: requestData)
        guard let appInfo = response.data as? LookinAppInfo else {
            throw LookinCoreError.protocolError(reason: "Expected LookinAppInfo in response")
        }
        return appInfo
    }

    /// Fetch the full view hierarchy.
    public func fetchHierarchy() async throws -> LookinHierarchyInfo {
        let requestData: NSDictionary = [
            "clientVersion": LOOKIN_SERVER_READABLE_VERSION as Any
        ]
        let response = try await sendRequest(type: LookinRequestTypeHierarchy, data: requestData)
        guard let hierarchy = response.data as? LookinHierarchyInfo else {
            throw LookinCoreError.protocolError(reason: "Expected LookinHierarchyInfo in response")
        }
        return hierarchy
    }

    /// Invoke a method on an object.
    public func invokeMethod(oid: UInt, selector: String) async throws -> (description: String?, object: Any?) {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid),
            "text": selector
        ]
        let response = try await sendRequest(type: LookinRequestTypeInvokeMethod, data: requestData)
        guard let dict = response.data as? NSDictionary else {
            throw LookinCoreError.protocolError(reason: "Expected NSDictionary in invoke response")
        }
        let description = dict["description"] as? String
        let object = dict["object"]
        return (description, object)
    }

    /// Submit an attribute modification.
    public func submitModification(_ modification: LookinAttributeModification) async throws {
        let response = try await sendRequest(type: LookinRequestTypeInbuiltAttrModification, data: modification)
        if let error = response.error {
            throw LookinCoreError.attributeModificationFailed(
                key: NSStringFromSelector(modification.setterSelector),
                reason: error.localizedDescription
            )
        }
    }

    /// Fetch all selector names for a class.
    public func fetchSelectorNames(className: String, hasArg: Bool) async throws -> [String] {
        let requestData: NSDictionary = [
            "className": className,
            "hasArg": NSNumber(value: hasArg)
        ]
        let response = try await sendRequest(type: LookinRequestTypeAllSelectorNames, data: requestData)
        guard let names = response.data as? [String] else {
            return []
        }
        return names
    }

    /// Submit a custom attribute modification.
    public func submitCustomModification(_ modification: LookinCustomAttrModification) async throws {
        let response = try await sendRequest(type: LookinRequestTypeCustomAttrModification, data: modification)
        if let error = response.error {
            throw LookinCoreError.attributeModificationFailed(
                key: modification.customSetterID ?? "unknown",
                reason: error.localizedDescription
            )
        }
    }

    /// Enable or disable a gesture recognizer.
    public func modifyGestureRecognizer(oid: UInt, enabled: Bool) async throws {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid),
            "enable": NSNumber(value: enabled)
        ]
        let response = try await sendRequest(type: LookinRequestTypeModifyRecognizerEnable, data: requestData)
        if let error = response.error {
            throw LookinCoreError.protocolError(reason: error.localizedDescription)
        }
    }

    /// Fetch details for a specific object by OID.
    public func fetchObject(oid: UInt) async throws -> Any? {
        let response = try await sendRequest(type: LookinRequestTypeFetchObject, data: NSNumber(value: oid))
        return response.data
    }

    /// Fetch all attribute groups for a specific object by OID.
    public func fetchAllAttrGroups(oid: UInt) async throws -> [LookinAttributesGroup] {
        let response = try await sendRequest(type: LookinRequestTypeAllAttrGroups, data: NSNumber(value: oid))
        guard let groups = response.data as? [LookinAttributesGroup] else {
            return []
        }
        return groups
    }

    // MARK: - Internal

    private func sendRequest(type: UInt32, data: NSObject?) async throws -> LookinConnectionResponseAttachment {
        guard let connection else {
            throw LookinCoreError.sessionNotConnected
        }

        // Serialize the request attachment
        let attachment = LookinConnectionAttachment()
        attachment.data = data

        let payload: Data
        do {
            payload = try NSKeyedArchiver.archivedData(withRootObject: attachment, requiringSecureCoding: true)
        } catch {
            throw LookinCoreError.protocolError(reason: "Serialization failed: \(error.localizedDescription)")
        }

        let tag = nextTag()
        let responseFrame = try await connection.sendRequest(type: type, tag: tag, payload: payload)

        // Deserialize the response
        let responseAttachment: LookinConnectionResponseAttachment
        do {
            guard let obj = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: LookinConnectionResponseAttachment.self,
                from: responseFrame.payload
            ) else {
                throw LookinCoreError.protocolError(reason: "Failed to deserialize response")
            }
            responseAttachment = obj
        } catch let error as LookinCoreError {
            throw error
        } catch {
            throw LookinCoreError.protocolError(reason: "Deserialization failed: \(error.localizedDescription)")
        }

        // Check for errors
        if let error = responseAttachment.error {
            throw LookinCoreError.protocolError(reason: error.localizedDescription)
        }
        if responseAttachment.appIsInBackground {
            throw LookinCoreError.appInBackground
        }

        return responseAttachment
    }
}
