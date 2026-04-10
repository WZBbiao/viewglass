import Foundation
import LookinSharedBridge

/// Live node query service that operates on real hierarchy data.
public final class LiveNodeQueryService: NodeQueryServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService
    private var cachedSnapshot: LKHierarchySnapshot?
    private let resolver = LKTargetResolver()

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    private func getSnapshot(sessionId: String) async throws -> LKHierarchySnapshot {
        if let cached = cachedSnapshot {
            return cached
        }
        let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
        cachedSnapshot = snapshot
        return snapshot
    }

    public func getNode(oid: UInt, sessionId: String) async throws -> LKNode {
        let snapshot = try await getSnapshot(sessionId: sessionId)
        guard let node = snapshot.findNode(oid: oid) else {
            throw LookinCoreError.nodeNotFound(oid: oid)
        }
        return node
    }

    public func getAttributes(oid: UInt, sessionId: String) async throws -> [LKAttributeGroup] {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)
                // Attribute inspection is user-facing; always get fresh data.
                let hierarchy = try await client.fetchHierarchy(forceRefresh: true)
                let targetOid = resolveAttributeObjectOid(nodeOid: oid, hierarchy: hierarchy)
                let groups = try await client.fetchAllAttrGroups(oid: targetOid)
                var result = groups.map { LKBridgeConverter.convertAttributesGroup($0) }

                // Inject runtime-read attributes the server doesn't include in its groups.
                // UISwitch.isOn and UISegmentedControl.selectedSegmentIndex are not registered
                // in the server's attribute group list, so we fetch them via invokeMethod.
                if let item = findItem(oid: oid, in: hierarchy.displayItems ?? []),
                   let viewObj = item.viewObject {
                    let className = viewObj.rawClassName() ?? ""
                    let classChain = viewObj.classChainList ?? [className]
                    let viewOid = UInt(viewObj.oid)
                    var runtimeAttrs: [LKAttribute] = []
                    if classChain.contains("UISwitch") || className == "UISwitch" {
                        if let (desc, _) = try? await client.invokeMethod(oid: viewOid, selector: "isOn") {
                            let isOn = desc == "1" || desc?.lowercased() == "yes" || desc?.lowercased() == "true"
                            runtimeAttrs.append(LKAttribute(key: "isOn", displayName: "isOn", value: .bool(isOn)))
                        }
                    } else if classChain.contains("UISegmentedControl") || className == "UISegmentedControl" {
                        if let (desc, _) = try? await client.invokeMethod(oid: viewOid, selector: "selectedSegmentIndex") {
                            let index = Double(desc ?? "0") ?? 0
                            runtimeAttrs.append(LKAttribute(key: "selectedSegmentIndex", displayName: "selectedSegmentIndex", value: .number(index)))
                        }
                    }
                    if !runtimeAttrs.isEmpty {
                        result.insert(LKAttributeGroup(groupName: "[viewglass_runtime]", attributes: runtimeAttrs), at: 0)
                    }
                }

                return result
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.nodeNotFound(oid: oid)
    }

    public func queryNodes(expression: String, sessionId: String) async throws -> [LKNode] {
        try await resolve(locator: .parse(expression), sessionId: sessionId).matches.map(\.node)
    }

    public func resolve(locator: LKLocator, sessionId: String) async throws -> LKResolvedTarget {
        let snapshot = try await getSnapshot(sessionId: sessionId)
        return try resolver.resolve(locator: locator, in: snapshot)
    }

    public func selectNode(oid: UInt, sessionId: String) async throws -> LKNode {
        return try await getNode(oid: oid, sessionId: sessionId)
    }

    private func resolveAttributeObjectOid(nodeOid: UInt, hierarchy: LookinHierarchyInfo) -> UInt {
        guard let items = hierarchy.displayItems else { return nodeOid }
        if let item = findItem(oid: nodeOid, in: items) {
            if let layerOid = item.layerObject?.oid {
                return UInt(layerOid)
            }
            if let viewOid = item.viewObject?.oid {
                return UInt(viewOid)
            }
        }
        return nodeOid
    }

    private func findItem(oid: UInt, in items: [LookinDisplayItem]) -> LookinDisplayItem? {
        for item in items {
            if UInt(item.layerObject?.oid ?? 0) == oid || UInt(item.viewObject?.oid ?? 0) == oid {
                return item
            }
            if let found = findItem(oid: oid, in: item.subitems ?? []) {
                return found
            }
        }
        return nil
    }

    private func shouldRetry(after error: Error) -> Bool {
        switch error {
        case let LookinCoreError.protocolError(reason):
            return reason.localizedCaseInsensitiveContains("connection closed")
                || reason.localizedCaseInsensitiveContains("connect failed")
        case let LookinCoreError.appNotFound(identifier):
            return !identifier.isEmpty
        default:
            return false
        }
    }
}
