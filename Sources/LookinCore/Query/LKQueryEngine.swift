import Foundation

public final class LKQueryEngine: Sendable {

    public init() {}

    /// Executes a query expression against a hierarchy snapshot.
    ///
    /// Supported expression syntax:
    /// - `UILabel` — match by class name or hosting controller class using fuzzy contains (case-insensitive)
    /// - `UILabel*` — match by class prefix
    /// - `*Label` — match by class suffix
    /// - `*View*` — match by class name containing substring (case-insensitive)
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
    /// - `contains:"text"` — full-text search: UILabel.text, button title, accessibilityLabel, accessibilityIdentifier (case-insensitive)
    /// - `text:"substring"` — alias for contains:
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

        // class:ClassName (fuzzy contains, case-insensitive)
        if expr.hasPrefix("class:") {
            let className = String(expr.dropFirst(6))
            return { self.matchesClass($0.className, query: className) }
        }

        // controller:ClassName (fuzzy contains, case-insensitive)
        if expr.hasPrefix("controller:") {
            let className = String(expr.dropFirst(11))
            return {
                guard let hostClass = $0.hostViewControllerClassName else { return false }
                return self.matchesClass(hostClass, query: className)
            }
        }

        // depth:N
        if expr.hasPrefix("depth:") {
            guard let depth = Int(expr.dropFirst(6)) else {
                throw LookinCoreError.querySyntaxError(expression: expr, reason: "Invalid depth value")
            }
            return { $0.depth == depth }
        }

        // parent:ClassName (fuzzy contains, case-insensitive)
        if expr.hasPrefix("parent:") {
            let parentClass = String(expr.dropFirst(7))
            return { node in
                guard let parentOid = node.parentOid else { return false }
                guard let parentNode = snapshot.findNode(oid: parentOid) else { return false }
                return self.matchesClass(parentNode.className, query: parentClass)
            }
        }

        // ancestor:ClassName — match nodes with any ancestor of the given class (fuzzy contains, case-insensitive)
        if expr.hasPrefix("ancestor:") {
            let ancestorClass = String(expr.dropFirst(9))
            return { node in
                var parentOid = node.parentOid
                while let pOid = parentOid {
                    guard let parent = snapshot.findNode(oid: pOid) else { break }
                    if self.matchesClass(parent.className, query: ancestorClass) { return true }
                    parentOid = parent.parentOid
                }
                return false
            }
        }

        // contains:"substring" — full-text search across all text fields (case-insensitive)
        // Matches: UILabel.text/button title (customDisplayTitle), accessibilityLabel, accessibilityIdentifier
        if expr.hasPrefix("contains:") {
            let raw = String(expr.dropFirst(9))
            let substring: String
            if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                substring = String(raw.dropFirst().dropLast())
            } else {
                substring = raw
            }
            return { node in
                (node.customDisplayTitle?.localizedCaseInsensitiveContains(substring) == true) ||
                (node.accessibilityLabel?.localizedCaseInsensitiveContains(substring) == true) ||
                (node.accessibilityIdentifier?.localizedCaseInsensitiveContains(substring) == true)
            }
        }

        // text:"substring" — alias for contains: (kept for backward compatibility)
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
                (node.accessibilityLabel?.localizedCaseInsensitiveContains(substring) == true) ||
                (node.accessibilityIdentifier?.localizedCaseInsensitiveContains(substring) == true)
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
        if expr.hasPrefix("*") && expr.hasSuffix("*") && expr.count > 2 {
            let substring = String(expr.dropFirst().dropLast())
            return {
                $0.className.localizedCaseInsensitiveContains(substring) ||
                ($0.hostViewControllerClassName?.localizedCaseInsensitiveContains(substring) ?? false)
            }
        }
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

        // Plain class name (default fuzzy contains, case-insensitive) — also match hosting controller class
        if expr.first?.isUpperCase == true || expr.first == "_" || expr.contains(".") {
            return {
                self.matchesClass($0.className, query: expr) ||
                ($0.hostViewControllerClassName.map { self.matchesClass($0, query: expr) } ?? false)
            }
        }

        throw LookinCoreError.querySyntaxError(
            expression: expr,
            reason: "Unrecognized expression '\(expr)'. " +
                "Class names must start with an uppercase letter (e.g. UILabel). " +
                "Supported atoms: UILabel, *Label, UI*, oid:N, tag:N, depth:N, " +
                "#accessibilityId, @\"label\", class:, controller:, parent:, ancestor:, " +
                "contains:\"text\", text:\"substring\", .visible, .hidden, .interactive, " +
                "AND, OR, NOT, (groups)"
        )
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

    private func matchesClass(_ candidate: String, query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return false }

        if candidate.localizedCaseInsensitiveContains(trimmedQuery) {
            return true
        }

        if let simpleName = candidate.split(separator: ".").last {
            return String(simpleName).localizedCaseInsensitiveContains(trimmedQuery)
        }

        return false
    }
}

private extension Character {
    var isUpperCase: Bool {
        isUppercase
    }
}
