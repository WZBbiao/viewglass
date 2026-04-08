import Foundation
import LookinCore

/// Resolves the session ID from the --session flag or the persisted session store.
func resolveSession(_ provided: String?, services: ServiceContainer) throws -> String {
    if let provided, !provided.isEmpty {
        return provided
    }
    if let live = services.session as? LiveSessionService {
        return try live.resolveSessionId(provided)
    }
    // Mock mode — use a default
    return provided ?? "mock"
}
