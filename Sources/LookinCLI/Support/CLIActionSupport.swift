import ArgumentParser
import Foundation
import LookinCore

enum CLIActionExecutionMode: String, ExpressibleByArgument {
    case auto
    case semantic
    case physical
}

/// Parse an OID argument in either "oid:N" or plain integer "N" format.
func parseOid(_ input: String) throws -> UInt {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    let raw = trimmed.hasPrefix("oid:") ? String(trimmed.dropFirst(4)) : trimmed
    guard let value = UInt(raw) else {
        throw ValidationError("Invalid OID '\(trimmed)'. Expected a non-negative integer or 'oid:N' format.")
    }
    return value
}

func parseCGPoint(argument: String, label: String) throws -> CGPoint {
    let numbers = argument
        .components(separatedBy: CharacterSet(charactersIn: "{}, "))
        .compactMap { component -> Double? in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : Double(trimmed)
        }
    guard numbers.count == 2 else {
        throw LookinCoreError.actionFailed(action: label, reason: "Expected point in the form 'x,y', got '\(argument)'.")
    }
    return CGPoint(x: numbers[0], y: numbers[1])
}

func formatCGPoint(_ point: CGPoint) -> String {
    "{\(formatCoordinate(point.x)),\(formatCoordinate(point.y))}"
}

private func formatCoordinate(_ value: Double) -> String {
    if value.rounded(.towardZero) == value {
        return String(Int(value))
    }
    return String(format: "%.2f", value)
}

func castLookinError(_ error: Error, fallbackAction: String) -> LookinCoreError {
    if let lookinError = error as? LookinCoreError {
        return lookinError
    }
    return .actionFailed(action: fallbackAction, reason: error.localizedDescription)
}

func canAttemptPhysicalFallback(error: LookinCoreError) -> Bool {
    switch error {
    case .attributeModificationFailed, .actionFailed, .protocolError:
        return true
    default:
        return false
    }
}

func unsupportedPhysicalAction(_ action: String) -> LookinCoreError {
    .actionFailed(
        action: action,
        reason: "Physical input is currently disabled because the previous implementation depended on macOS focus-stealing automation. Use semantic mode instead."
    )
}

func resolveActionTarget(
    _ input: String,
    services: ServiceContainer,
    sessionId: String,
    action: String,
    capability: String? = nil
) async throws -> LKResolvedMatch {
    if let resolved = try? decodeResolvedTarget(from: input) {
        if let selected = resolved.selectedTarget {
            return try ensureCapability(selected, action: action, capability: capability)
        }
        throw LookinCoreError.actionFailed(
            action: action,
            reason: "Locator matched \(resolved.matches.count) targets. Refine the locator or pass a selectedTarget payload."
        )
    }

    if let match = try? decodeResolvedMatch(from: input) {
        return try ensureCapability(match, action: action, capability: capability)
    }

    let resolved = try await services.nodeQuery.resolve(locator: .parse(input), sessionId: sessionId)
    guard let selected = resolved.selectedTarget else {
        let reason = resolved.matches.isEmpty
            ? "Locator matched no targets."
            : "Locator matched \(resolved.matches.count) targets. Refine the locator or disambiguate first."
        throw LookinCoreError.actionFailed(action: action, reason: reason)
    }
    return try ensureCapability(selected, action: action, capability: capability)
}

private func ensureCapability(
    _ match: LKResolvedMatch,
    action: String,
    capability: String?
) throws -> LKResolvedMatch {
    guard let capability else { return match }
    if let value = match.capabilities[capability], !value.supported {
        throw LookinCoreError.actionFailed(
            action: action,
            reason: value.reason ?? "target does not support \(capability)"
        )
    }
    return match
}

private func decodeResolvedTarget(from input: String) throws -> LKResolvedTarget {
    let data = Data(input.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(LKResolvedTarget.self, from: data)
}

private func decodeResolvedMatch(from input: String) throws -> LKResolvedMatch {
    let data = Data(input.utf8)
    let decoder = JSONDecoder()
    return try decoder.decode(LKResolvedMatch.self, from: data)
}
