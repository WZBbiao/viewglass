import Foundation

public final class MockHierarchyService: HierarchyServiceProtocol, @unchecked Sendable {
    public var mockSnapshot: LKHierarchySnapshot?
    public var shouldFail = false

    public init() {
        mockSnapshot = Self.makeSampleSnapshot()
    }

    public func fetchHierarchy(sessionId: String) async throws -> LKHierarchySnapshot {
        if shouldFail { throw LookinCoreError.sessionNotConnected }
        guard let snapshot = mockSnapshot else {
            throw LookinCoreError.sessionNotConnected
        }
        return snapshot
    }

    public func refreshHierarchy(sessionId: String) async throws -> LKHierarchySnapshot {
        try await fetchHierarchy(sessionId: sessionId)
    }

    public static func makeSampleSnapshot() -> LKHierarchySnapshot {
        let buttonLabel = LKNode(
            oid: 5, className: "UILabel", address: "0x600005",
            frame: LKRect(x: 10, y: 5, width: 80, height: 20),
            bounds: LKRect(x: 0, y: 0, width: 80, height: 20),
            alpha: 1.0, isUserInteractionEnabled: false,
            accessibilityLabel: "Tap me",
            depth: 4, parentOid: 4
        )
        let button = LKNode(
            oid: 4, className: "UIButton", address: "0x600004",
            frame: LKRect(x: 50, y: 400, width: 100, height: 44),
            bounds: LKRect(x: 0, y: 0, width: 100, height: 44),
            alpha: 1.0, isUserInteractionEnabled: true,
            depth: 3, parentOid: 3, childrenOids: [5]
        )
        let label = LKNode(
            oid: 6, className: "UILabel", address: "0x600006",
            frame: LKRect(x: 20, y: 100, width: 200, height: 30),
            bounds: LKRect(x: 0, y: 0, width: 200, height: 30),
            alpha: 1.0, isUserInteractionEnabled: false,
            accessibilityLabel: "Welcome",
            depth: 3, parentOid: 3
        )
        let overlappingView = LKNode(
            oid: 7, className: "UIView", address: "0x600007",
            frame: LKRect(x: 60, y: 405, width: 80, height: 30),
            bounds: LKRect(x: 0, y: 0, width: 80, height: 30),
            alpha: 1.0, isUserInteractionEnabled: true,
            depth: 3, parentOid: 3
        )
        let hiddenButton = LKNode(
            oid: 8, className: "UIButton", address: "0x600008",
            frame: LKRect(x: 200, y: 600, width: 100, height: 44),
            bounds: LKRect(x: 0, y: 0, width: 100, height: 44),
            isHidden: true, alpha: 1.0, isUserInteractionEnabled: true,
            depth: 3, parentOid: 3
        )
        let contentView = LKNode(
            oid: 3, className: "UIView", address: "0x600003",
            frame: LKRect(x: 0, y: 0, width: 390, height: 844),
            bounds: LKRect(x: 0, y: 0, width: 390, height: 844),
            alpha: 1.0, isUserInteractionEnabled: true,
            depth: 2, parentOid: 2, childrenOids: [4, 6, 7, 8]
        )
        let viewController = LKNode(
            oid: 2, className: "UIView", address: "0x600002",
            frame: LKRect(x: 0, y: 0, width: 390, height: 844),
            bounds: LKRect(x: 0, y: 0, width: 390, height: 844),
            alpha: 1.0, isUserInteractionEnabled: true,
            customDisplayTitle: "ViewController.view",
            depth: 1, parentOid: 1, childrenOids: [3]
        )
        let window = LKNode(
            oid: 1, className: "UIWindow", address: "0x600001",
            frame: LKRect(x: 0, y: 0, width: 390, height: 844),
            bounds: LKRect(x: 0, y: 0, width: 390, height: 844),
            alpha: 1.0, isUserInteractionEnabled: true,
            depth: 0, childrenOids: [2]
        )

        let tree = LKNodeTree(
            node: window,
            children: [
                LKNodeTree(
                    node: viewController,
                    children: [
                        LKNodeTree(
                            node: contentView,
                            children: [
                                LKNodeTree(
                                    node: button,
                                    children: [LKNodeTree(node: buttonLabel)]
                                ),
                                LKNodeTree(node: label),
                                LKNodeTree(node: overlappingView),
                                LKNodeTree(node: hiddenButton),
                            ]
                        )
                    ]
                )
            ]
        )

        let app = LKAppDescriptor(
            appName: "DemoApp",
            bundleIdentifier: "com.example.demo",
            appVersion: "1.0.0",
            deviceName: "iPhone 15 Pro",
            deviceType: .simulator,
            port: 47164,
            serverVersion: "1.2.8"
        )

        return LKHierarchySnapshot(
            appInfo: app,
            windows: [tree],
            serverVersion: "1.2.8",
            screenScale: 3.0,
            screenSize: LKRect(x: 0, y: 0, width: 390, height: 844)
        )
    }
}
