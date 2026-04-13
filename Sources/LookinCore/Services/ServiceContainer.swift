import Foundation

public final class ServiceContainer: @unchecked Sendable {
    public let session: SessionServiceProtocol
    public let hierarchy: HierarchyServiceProtocol
    public let nodeQuery: NodeQueryServiceProtocol
    public let screenshot: ScreenshotServiceProtocol
    public let mutation: MutationServiceProtocol
    public let export: ExportServiceProtocol
    public let diagnostics: DiagnosticsService

    public init(
        session: SessionServiceProtocol,
        hierarchy: HierarchyServiceProtocol,
        nodeQuery: NodeQueryServiceProtocol,
        screenshot: ScreenshotServiceProtocol,
        mutation: MutationServiceProtocol,
        export: ExportServiceProtocol,
        diagnostics: DiagnosticsService
    ) {
        self.session = session
        self.hierarchy = hierarchy
        self.nodeQuery = nodeQuery
        self.screenshot = screenshot
        self.mutation = mutation
        self.export = export
        self.diagnostics = diagnostics
    }

    public static func makeMock() -> ServiceContainer {
        let session = MockSessionService()
        let hierarchy = MockHierarchyService()
        return ServiceContainer(
            session: session,
            hierarchy: hierarchy,
            nodeQuery: MockNodeQueryService(),
            screenshot: MockScreenshotService(),
            mutation: MockMutationService(),
            export: MockExportService(),
            diagnostics: DiagnosticsService()
        )
    }

    public static func makeLive() -> ServiceContainer {
        let store = SessionStore()
        let session = LiveSessionService(store: store)
        let hierarchy = LiveHierarchyService(sessionService: session)
        return ServiceContainer(
            session: session,
            hierarchy: hierarchy,
            nodeQuery: LiveNodeQueryService(sessionService: session, hierarchyService: hierarchy),
            screenshot: LiveScreenshotService(sessionService: session, hierarchyService: hierarchy),
            mutation: LiveMutationService(sessionService: session),
            export: LiveExportService(),
            diagnostics: DiagnosticsService()
        )
    }

    /// Create a service container based on mode flag.
    public static func make(live: Bool) -> ServiceContainer {
        live ? makeLive() : makeMock()
    }

    /// Gracefully shut down all live connections.
    /// Must be called before CLI process exits to ensure clean TCP close.
    public func shutdown() {
        if let liveSession = session as? LiveSessionService {
            liveSession.disconnectAll()
        }
    }
}
