import Foundation

public final class MockNodeQueryService: NodeQueryServiceProtocol, @unchecked Sendable {
    public var mockHierarchy: LKHierarchySnapshot?
    public var selectedOid: UInt?
    public var shouldFail = false
    private let resolver = LKTargetResolver()

    public init() {
        mockHierarchy = MockHierarchyService.makeSampleSnapshot()
    }

    public func getNode(oid: UInt, sessionId: String) async throws -> LKNode {
        if shouldFail { throw LookinCoreError.sessionNotConnected }
        guard let hierarchy = mockHierarchy else {
            throw LookinCoreError.sessionNotConnected
        }
        guard let node = hierarchy.findNode(oid: oid) else {
            throw LookinCoreError.nodeNotFound(oid: oid)
        }
        return node
    }

    public func getAttributes(oid: UInt, sessionId: String) async throws -> [LKAttributeGroup] {
        let node = try await getNode(oid: oid, sessionId: sessionId)
        return node.attributeGroups ?? []
    }

    public func queryNodes(expression: String, sessionId: String) async throws -> [LKNode] {
        try await resolve(locator: .parse(expression), sessionId: sessionId).matches.map(\.node)
    }

    public func resolve(locator: LKLocator, sessionId: String) async throws -> LKResolvedTarget {
        if shouldFail { throw LookinCoreError.sessionNotConnected }
        guard let hierarchy = mockHierarchy else {
            throw LookinCoreError.sessionNotConnected
        }
        return try resolver.resolve(locator: locator, in: hierarchy)
    }

    public func selectNode(oid: UInt, sessionId: String) async throws -> LKNode {
        let node = try await getNode(oid: oid, sessionId: sessionId)
        selectedOid = oid
        return node
    }

    public func nodeCount(expression: String, sessionId: String) async throws -> Int {
        return try await queryNodes(expression: expression, sessionId: sessionId).count
    }
}
