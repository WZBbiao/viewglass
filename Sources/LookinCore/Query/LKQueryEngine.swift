import Foundation

public final class LKQueryEngine: Sendable {

    public init() {}

    /// Executes a query expression against a hierarchy snapshot.
    ///
    /// Supported expression syntax:
    /// - `UILabel` — match by class name (exact)
    /// - `UILabel*` — match by class prefix
    /// - `*Label` — match by class suffix
    /// - `#accessibilityIdentifier` — match by accessibility identifier
    /// - `@"accessibility label text"` — match by accessibility label
    /// - `.hidden` — filter to hidden nodes
    /// - `.visible` — filter to visible nodes
    /// - `.interactive` — filter to user interaction enabled nodes
    /// - `oid:123` — match by object ID
    /// - `tag:42` — match by tag
    /// - `class:UIButton` — explicit class match
    /// - `controller:UIAlertController` — match by hosting UIViewController class
    /// - `depth:3` — match by depth level
    /// - `parent:UIView` — match nodes whose direct parent class matches
    /// - `ancestor:UIScrollView` — match nodes with any ancestor of the given class
    /// - `contains:"text"` — match nodes whose accessibilityLabel contains substring (case-insensitive)
    /// - `text:"substring"` — match nodes whose visible text (UILabel.text / button title) contains substring (case-insensitive)
    /// - Logical operators: `AND`, `OR`, `NOT` (case insensitive)
    /// - Parentheses for grouping: `(UIButton OR UILabel) AND .visible`
    public func execute(expression: String, on snapshot: LKHierarchySnapshot) throws -> [LKNode] {
        let trimmed = expression.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw LookinCoreError.querySyntaxError(expression: expression, reason: "Empty expression")
        }

        let predicate = try parse(trimmed, snapshot: snapshot)
        return snapshot.flatNodes.filter(predicate)
    }

    private func parse(_ expr: String, snapshot: LKHierarchySnapshot) throws -> (LKNode) -> Bool {
        // Handle OR at top level (lowest precedence)
        if let parts = splitTopLevel(expr, separator: "OR") {
            let predicates = try parts.map { try parse($0.trimmingCharacters(in: .whitespaces), snapshot: snapshot) }
            return { node in predicates.contains { $0(node) } }
        }

        // Handle AND
        if let parts = splitTopLevel(expr, separator: "AND") {
            let predicates = try parts.map { try parse($0.trimmingCharacters(in: .whitespaces), snapshot: snapshot) }
            return { node in predicates.allSatisfy { $0(node) } }
        }

        // Handle NOT
        if expr.uppercased().hasPrefix("NOT ") {
            let rest = String(expr.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            let inner = try parse(rest, snapshot: snapshot)
            return { node in !inner(node) }
        }

        // Handle parentheses
        if expr.hasPrefix("(") && expr.hasSuffix(")") {
            let inner = String(expr.dropFirst().dropLast())
            return try parse(inner, snapshot: snapshot)
        }

        // Atomic expressions
        return try parseAtom(expr, snapshot: snapshot)
    }

    private func parseAtom(_ expr: String, snapshot: LKHierarchySnapshot) throws -> (LKNode) -> Bool {
        // .hidden, .visible, .interactive
        if expr == ".hidden" {
            return { !$0.isVisible }
        }
        if expr == ".visible" {
            return { $0.isVisible }
        }
        if expr == ".interactive" {
            return { $0.isUserInteractionEnabled }
        }

        // oid:123
        if expr.hasPrefix("oid:") {
            guard let oid = UInt(expr.dropFirst(4)) else {
                throw LookinCoreError.querySyntaxError(expression: expr, reason: "Invalid oid value")
            }
            return { $0.oid == oid }
        }

        // tag:42
        if expr.hasPrefix("tag:") {
            guard let tag = Int(expr.dropFirst(4)) else {
                throw LookinCoreError.querySyntaxError(expression: expr, reason: "Invalid tag value")
            }
            return { $0.tag == tag }
        }

        // class:ClassName
        if expr.hasPrefix("class:") {
            let className = String(expr.dropFirst(6))
            return { $0.className == className }
        }

        // controller:ClassName
        if expr.hasPrefix("controller:") {
            let className = String(expr.dropFirst(11))
            return {
                guard let hostClass = $0.hostViewControllerClassName else { return false }
                return hostClass == className || hostClass.hasSuffix(".\(className)")
            }
        }

        // depth:N
        if expr.hasPrefix("depth:") {
            guard let depth = Int(expr.dropFirst(6)) else {
                throw LookinCoreError.querySyntaxError(expression: expr, reason: "Invalid depth value")
            }
            return { $0.depth == depth }
        }

        // parent:ClassName
        if expr.hasPrefix("parent:") {
            let parentClass = String(expr.dropFirst(7))
            return { node in
                guard let parentOid = node.parentOid else { return false }
                guard let parentNode = snapshot.findNode(oid: parentOid) else { return false }
                return parentNode.className == parentClass
            }
        }

        // ancestor:ClassName — match nodes with any ancestor of the given class
        if expr.hasPrefix("ancestor:") {
            let ancestorClass = String(expr.dropFirst(9))
            return { node in
                var parentOid = node.parentOid
                while let pOid = parentOid {
                    guard let parent = snapshot.findNode(oid: pOid) else { break }
                    if parent.className == ancestorClass { return true }
                    parentOid = parent.parentOid
                }
                return false
            }
        }

        // contains:"substring" — accessibilityLabel contains (case-insensitive)
        if expr.hasPrefix("contains:") {
            let raw = String(expr.dropFirst(9))
            let substring: String
            if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                substring = String(raw.dropFirst().dropLast())
            } else {
                substring = raw
            }
            return { $0.accessibilityLabel?.localizedCaseInsensitiveContains(substring) == true }
        }

        // text:"substring" — visible display text contains substring (case-insensitive)
        // Matches customDisplayTitle (UILabel.text, UIButton.title, etc.) or accessibilityLabel.
        if expr.hasPrefix("text:") {
            let raw = String(expr.dropFirst(5))
            let substring: String
            if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                substring = String(raw.dropFirst().dropLast())
            } else {
                substring = raw
            }
            return { node in
                (node.customDisplayTitle?.localizedCaseInsensitiveContains(substring) == true) ||
                (node.accessibilityLabel?.localizedCaseInsensitiveContains(substring) == true)
            }
        }

        // #accessibilityIdentifier
        if expr.hasPrefix("#") {
            let identifier = String(expr.dropFirst())
            return { $0.accessibilityIdentifier == identifier }
        }

        // @"accessibility label"
        if expr.hasPrefix("@\"") && expr.hasSuffix("\"") {
            let label = String(expr.dropFirst(2).dropLast())
            return { $0.accessibilityLabel == label }
        }
        if expr.hasPrefix("@") {
            let label = String(expr.dropFirst())
            return { $0.accessibilityLabel == label }
        }

        // Wildcard class matching
        if expr.hasPrefix("*") {
            let suffix = String(expr.dropFirst())
            return {
                $0.className.hasSuffix(suffix) ||
                ($0.hostViewControllerClassName?.hasSuffix(suffix) ?? false)
            }
        }
        if expr.hasSuffix("*") {
            let prefix = String(expr.dropLast())
            return {
                $0.className.hasPrefix(prefix) ||
                ($0.hostViewControllerClassName?.hasPrefix(prefix) ?? false)
            }
        }

        // Plain class name (exact match) — also match hosting controller class
        if expr.first?.isUpperCase == true || expr.first == "_" || expr.contains(".") {
            return {
                $0.className == expr ||
                $0.hostViewControllerClassName == expr ||
                ($0.hostViewControllerClassName?.hasSuffix(".\(expr)") ?? false)
            }
        }

        throw LookinCoreError.querySyntaxError(expression: expr, reason: "Unrecognized expression")
    }

    /// Splits an expression by a logical operator at the top level
    /// (not inside parentheses or quoted strings).
    private func splitTopLevel(_ expr: String, separator: String) -> [String]? {
        var parenDepth = 0
        var inQuote = false
        var parts: [String] = []
        var current = ""
        let tokens = expr.components(separatedBy: " ")
        var i = 0

        while i < tokens.count {
            let token = tokens[i]

            // Track quote state — toggle on each unescaped "
            let quoteCount = token.filter { $0 == "\"" }.count
            if quoteCount % 2 != 0 {
                inQuote.toggle()
            }

            if token.uppercased() == separator && parenDepth == 0 && !inQuote
                && !current.trimmingCharacters(in: .whitespaces).isEmpty
            {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                if !inQuote {
                    parenDepth += token.filter({ $0 == "(" }).count
                    parenDepth -= token.filter({ $0 == ")" }).count
                }
                current += (current.isEmpty ? "" : " ") + token
            }
            i += 1
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespaces))
        }

        return parts.count > 1 ? parts : nil
    }
}

private extension Character {
    var isUpperCase: Bool {
        isUppercase
    }
}
