import ArgumentParser
import Foundation
import LookinCore

enum CLIActionExecutionMode: String, ExpressibleByArgument {
    case auto
    case semantic
    case physical
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
