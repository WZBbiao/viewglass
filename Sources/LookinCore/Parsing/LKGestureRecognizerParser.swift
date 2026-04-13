import Foundation

public enum LKGestureRecognizerParser {
    public static func parse(_ text: String) -> [LKGestureInfo] {
        let normalized = text.replacingOccurrences(of: "\\\"", with: "\"")
        let lines = normalized
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("<") && $0.contains("GestureRecognizer") }

        return lines.compactMap(parseLine)
    }

    private static func parseLine(_ line: String) -> LKGestureInfo? {
        let trimmed = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let recognizerClass = firstMatch(in: trimmed, pattern: #"^<([A-Za-z_][A-Za-z0-9_]*)\:"#)
        else {
            return nil
        }

        let address = firstMatch(in: trimmed, pattern: #"^<[A-Za-z_][A-Za-z0-9_]*:\s*([^;>]+)"#)
        let idValue = firstMatch(in: trimmed, pattern: #"id\s*=\s*([0-9]+)"#).flatMap(UInt.init)
        let state = firstMatch(in: trimmed, pattern: #"state\s*=\s*([^;>]+)"#)
        let viewClass = firstMatch(in: trimmed, pattern: #"view\s*=\s*<([A-Za-z_][A-Za-z0-9_]*)\:"#)
        let actions = allActionMatches(in: trimmed)

        return LKGestureInfo(
            recognizerClass: recognizerClass,
            recognizerAddress: address,
            recognizerId: idValue,
            state: state,
            viewClass: viewClass,
            actions: actions,
            rawDescription: trimmed
        )
    }

    private static func allActionMatches(in text: String) -> [LKGestureActionInfo] {
        guard let regex = try? NSRegularExpression(
            pattern: #"action=([A-Za-z_][A-Za-z0-9_:]*),\s*target=<([A-Za-z_][A-Za-z0-9_\.]*)"#
        ) else {
            return []
        }

        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsrange).compactMap { match in
            guard
                let selectorRange = Range(match.range(at: 1), in: text),
                let targetRange = Range(match.range(at: 2), in: text)
            else {
                return nil
            }
            return LKGestureActionInfo(
                selector: String(text[selectorRange]),
                targetClass: String(text[targetRange])
            )
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: nsrange),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
