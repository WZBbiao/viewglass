import Foundation
import LookinSharedBridge

/// High-level protocol client that handles serialization and request lifecycle.
public final class LKProtocolClient: @unchecked Sendable {
    private var connection: LKTCPConnection?
    private var tagCounter: UInt32 = 1

    // MARK: - Hierarchy cache
    //
    // fetchHierarchy() is called by LiveMutationService before every action to resolve
    // nodeOid → objectOid + classChain.  OIDs are memory addresses of ObjC objects and
    // remain stable as long as the view hierarchy doesn't structurally change (add/remove
    // views).  Caching the last-fetched hierarchy eliminates a round-trip per action.
    //
    // Invalidation policy:
    //   • After submitModification() – the server broadcasts display-item push frames,
    //     indicating the UI changed; OIDs of existing nodes are still valid but we
    //     invalidate as a safe default.
    //   • After invokeMethod() – a custom method could restructure the hierarchy.
    //   • TTL = 30 s – safety net for long-lived daemon connections.
    //   • forceRefresh: true – used by explicit hierarchy commands (viewglass hierarchy).
    private var _cachedHierarchy: LookinHierarchyInfo?
    private var _hierarchyCachedAt: Date?
    private let _cacheLock = NSLock()
    private static let hierarchyCacheTTL: TimeInterval = 30

    public init() {}

    /// Try to connect to a LookinServer on a specific port.
    public func connect(host: String = "127.0.0.1", port: Int) async throws {
        let conn = LKTCPConnection(host: host, port: port)
        try await conn.connect()
        self.connection = conn

        // Send ping to verify connection
        try await ping()
    }

    deinit {
        connection?.disconnect()
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

    private func describe(_ error: NSError) -> String {
        let description = error.localizedDescription
        let recovery = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
        if let recovery, !recovery.isEmpty, recovery != description {
            return "\(description) \(recovery)"
        }
        return description
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
    ///
    /// - Parameter forceRefresh: When `true`, always fetches from the server even if a
    ///   cached result is available.  Pass `true` for explicit user-facing hierarchy
    ///   commands; leave `false` (default) for internal mutation/action use where a
    ///   cached hierarchy is sufficient to resolve OID mappings.
    public func fetchHierarchy(forceRefresh: Bool = false) async throws -> LookinHierarchyInfo {
        if !forceRefresh {
            _cacheLock.lock()
            let cached = _cachedHierarchy
            let cachedAt = _hierarchyCachedAt
            _cacheLock.unlock()
            if let h = cached,
               let t = cachedAt,
               Date().timeIntervalSince(t) < Self.hierarchyCacheTTL {
                return h
            }
        }
        let requestData: NSDictionary = [
            "clientVersion": LOOKIN_SERVER_READABLE_VERSION as Any
        ]
        let response = try await sendRequest(type: LookinRequestTypeHierarchy, data: requestData)
        guard let hierarchy = response.data as? LookinHierarchyInfo else {
            throw LookinCoreError.protocolError(reason: "Expected LookinHierarchyInfo in response")
        }
        _cacheLock.lock()
        _cachedHierarchy = hierarchy
        _hierarchyCachedAt = Date()
        _cacheLock.unlock()
        return hierarchy
    }

    /// Discard the cached hierarchy.  Call after any operation that may structurally
    /// change the view tree so the next fetchHierarchy() gets a fresh snapshot.
    public func invalidateHierarchyCache() {
        _cacheLock.lock()
        _cachedHierarchy = nil
        _hierarchyCachedAt = nil
        _cacheLock.unlock()
    }

    /// Fetch display item details, including screenshots and basis visual data.
    public func fetchHierarchyDetails(
        taskPackages: [LookinStaticAsyncUpdateTasksPackage]
    ) async throws -> [LookinDisplayItemDetail] {
        let responses = try await sendRequestAttachments(
            type: LookinRequestTypeHierarchyDetails,
            data: taskPackages as NSArray
        )
        var details: [LookinDisplayItemDetail] = []
        for response in responses {
            if let batch = response.data as? [LookinDisplayItemDetail] {
                details.append(contentsOf: batch)
            } else if let single = response.data as? LookinDisplayItemDetail {
                details.append(single)
            }
        }
        return details
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
        let rawDescription = dict["description"] as? String
        let description = (rawDescription == LookinStringFlag_VoidReturn || rawDescription == "LOOKIN_TAG_RETURN_VALUE_VOID")
            ? "The method was invoked successfully and no value was returned."
            : rawDescription
        let object = dict["object"]
        // A custom method may restructure the view hierarchy.
        invalidateHierarchyCache()
        return (description, object)
    }

    /// Submit an attribute modification.
    /// Uses fire-and-forget: sends the request and reads the response, then disconnects
    /// cleanly to avoid leaving stale push data in the TCP buffer.
    public func submitModification(_ modification: LookinAttributeModification) async throws {
        guard let connection else { throw LookinCoreError.sessionNotConnected }

        let response = try await sendRequest(type: LookinRequestTypeInbuiltAttrModification, data: modification)
        if let error = response.error {
            throw LookinCoreError.attributeModificationFailed(
                key: NSStringFromSelector(modification.setterSelector),
                reason: describe(error as NSError)
            )
        }

        // After a modification, the server sends push frames with display item updates.
        // We must drain them to keep the connection clean for the next request.
        // drainPendingData is now truly async – no thread is blocked during the wait.
        await connection.drainPendingData(timeoutMs: 2000)

        // The UI has changed; future hierarchy lookups must go to the server.
        invalidateHierarchyCache()
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
                reason: describe(error as NSError)
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
            throw LookinCoreError.protocolError(reason: describe(error as NSError))
        }
    }

    public func triggerSemanticTap(oid: UInt) async throws -> String? {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid)
        ]
        let response = try await sendRequest(type: LookinRequestTypeSemanticTap, data: requestData)
        if let dict = response.data as? NSDictionary {
            return dict["detail"] as? String
        }
        if let detail = response.data as? NSString {
            return detail as String
        }
        return nil
    }

    public func triggerSemanticLongPress(oid: UInt) async throws -> String? {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid)
        ]
        let response = try await sendRequest(type: LookinRequestTypeSemanticLongPress, data: requestData)
        if let dict = response.data as? NSDictionary {
            return dict["detail"] as? String
        }
        if let detail = response.data as? NSString {
            return detail as String
        }
        return nil
    }

    public func triggerSemanticDismiss(oid: UInt) async throws -> String? {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid)
        ]
        let response = try await sendRequest(type: LookinRequestTypeSemanticDismiss, data: requestData)
        if let dict = response.data as? NSDictionary {
            return dict["detail"] as? String
        }
        return nil
    }

    public func triggerSemanticTextInput(oid: UInt, text: String) async throws -> String? {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid),
            "text": text
        ]
        let response = try await sendRequest(type: LookinRequestTypeSemanticTextInput, data: requestData)
        if let dict = response.data as? NSDictionary {
            return dict["detail"] as? String
        }
        if let detail = response.data as? NSString {
            return detail as String
        }
        return nil
    }

    public func fetchHighResolutionScreenScreenshot() async throws -> Data {
        let response = try await sendRequest(type: LookinRequestTypeHighResolutionScreenshot, data: [:] as NSDictionary)
        guard let data = response.data as? Data, !data.isEmpty else {
            throw LookinCoreError.protocolError(reason: "Expected non-empty screenshot data in high-resolution screen response")
        }
        return data
    }

    public func fetchHighResolutionNodeScreenshot(oid: UInt) async throws -> Data {
        let requestData: NSDictionary = [
            "oid": NSNumber(value: oid)
        ]
        let response = try await sendRequest(type: LookinRequestTypeHighResolutionScreenshot, data: requestData)
        guard let data = response.data as? Data, !data.isEmpty else {
            throw LookinCoreError.protocolError(reason: "Expected non-empty screenshot data in high-resolution node response")
        }
        return data
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

    /// Send a request and handle multi-frame responses.
    /// The Lookin protocol may split large responses into multiple frames,
    /// indicated by dataTotalCount > 0 in the response attachment.
    private func sendRequest(type: UInt32, data: NSObject?) async throws -> LookinConnectionResponseAttachment {
        let attachments = try await sendRequestAttachments(type: type, data: data)
        guard let first = attachments.first else {
            throw LookinCoreError.protocolError(reason: "Empty response")
        }
        return first
    }

    private func sendRequestAttachments(
        type: UInt32,
        data: NSObject?
    ) async throws -> [LookinConnectionResponseAttachment] {
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
        let firstFrame = try await connection.sendRequest(type: type, tag: tag, payload: payload)

        // Deserialize the first response
        let firstAttachment = try deserializeResponse(firstFrame.payload)
        var attachments = [firstAttachment]

        // Check for errors immediately
        if let error = firstAttachment.error {
            throw LookinCoreError.protocolError(reason: describe(error as NSError))
        }
        if firstAttachment.appIsInBackground {
            throw LookinCoreError.appInBackground
        }

        // Handle multi-frame responses
        // If dataTotalCount > 0, the server will send more frames with the same tag
        if firstAttachment.dataTotalCount > 0 {
            var receivedCount = firstAttachment.currentDataCount
            let totalCount = firstAttachment.dataTotalCount

            // Read remaining frames until we have all responses
            while receivedCount < totalCount {
                let nextFrame = try await connection.receiveFrame()
                let nextAttachment = try deserializeResponse(nextFrame.payload)
                receivedCount += nextAttachment.currentDataCount
                attachments.append(nextAttachment)

                // Check for errors in subsequent frames
                if let error = nextAttachment.error {
                    throw LookinCoreError.protocolError(reason: describe(error as NSError))
                }
            }
        }

        return attachments
    }

    private func deserializeResponse(_ data: Data) throws -> LookinConnectionResponseAttachment {
        do {
            guard let obj = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: LookinConnectionResponseAttachment.self,
                from: data
            ) else {
                throw LookinCoreError.protocolError(reason: "Failed to deserialize response")
            }
            return obj
        } catch let error as LookinCoreError {
            throw error
        } catch {
            do {
                if let obj = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? LookinConnectionResponseAttachment {
                    return obj
                }
            } catch {
                // Fall through to the original secure-coding failure below.
            }
            throw LookinCoreError.protocolError(reason: "Deserialization failed: \(error.localizedDescription)")
        }
    }
}
