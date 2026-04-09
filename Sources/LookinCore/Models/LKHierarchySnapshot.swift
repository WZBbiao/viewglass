import Foundation

public struct LKHierarchySnapshot: Codable, Equatable, Sendable {
    public let snapshotId: String
    public let appInfo: LKAppDescriptor
    public let windows: [LKNodeTree]
    public let fetchedAt: Date
    public let serverVersion: String?
    public let screenScale: Double
    public let screenSize: LKRect

    public init(
        snapshotId: String = UUID().uuidString,
        appInfo: LKAppDescriptor,
        windows: [LKNodeTree],
        fetchedAt: Date = Date(),
        serverVersion: String? = nil,
        screenScale: Double = 2.0,
        screenSize: LKRect = LKRect(x: 0, y: 0, width: 390, height: 844)
    ) {
        self.snapshotId = snapshotId
        self.appInfo = appInfo
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.serverVersion = serverVersion
        self.screenScale = screenScale
        self.screenSize = screenSize
    }

    public var flatNodes: [LKNode] {
        windows.flatMap { $0.flatten() }
    }

    public func findNode(oid: UInt) -> LKNode? {
        flatNodes.first {
            $0.oid == oid ||
            $0.primaryOid == oid ||
            $0.viewOid == oid ||
            $0.layerOid == oid ||
            $0.hostViewControllerOid == oid
        }
    }

    public func findNodes(className: String) -> [LKNode] {
        flatNodes.filter { $0.className == className }
    }

    public var totalNodeCount: Int {
        flatNodes.count
    }

    enum CodingKeys: String, CodingKey {
        case snapshotId
        case appInfo
        case windows
        case fetchedAt
        case serverVersion
        case screenScale
        case screenSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshotId = try container.decodeIfPresent(String.self, forKey: .snapshotId) ?? UUID().uuidString
        self.appInfo = try container.decode(LKAppDescriptor.self, forKey: .appInfo)
        self.windows = try container.decode([LKNodeTree].self, forKey: .windows)
        self.fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        self.serverVersion = try container.decodeIfPresent(String.self, forKey: .serverVersion)
        self.screenScale = try container.decodeIfPresent(Double.self, forKey: .screenScale) ?? 2.0
        self.screenSize = try container.decodeIfPresent(LKRect.self, forKey: .screenSize) ?? LKRect(x: 0, y: 0, width: 390, height: 844)
    }
}

public struct LKNodeTree: Codable, Equatable, Sendable {
    public let node: LKNode
    public let children: [LKNodeTree]

    public init(node: LKNode, children: [LKNodeTree] = []) {
        self.node = node
        self.children = children
    }

    public func flatten() -> [LKNode] {
        var result = [node]
        for child in children {
            result.append(contentsOf: child.flatten())
        }
        return result
    }

    public func find(oid: UInt) -> LKNodeTree? {
        if node.oid == oid || node.primaryOid == oid || node.viewOid == oid || node.layerOid == oid || node.hostViewControllerOid == oid {
            return self
        }
        for child in children {
            if let found = child.find(oid: oid) { return found }
        }
        return nil
    }

    public func filter(_ predicate: (LKNode) -> Bool) -> [LKNode] {
        var result: [LKNode] = []
        if predicate(node) { result.append(node) }
        for child in children {
            result.append(contentsOf: child.filter(predicate))
        }
        return result
    }
}
