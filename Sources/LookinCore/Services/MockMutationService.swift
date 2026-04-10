import Foundation
import CoreGraphics

public final class MockMutationService: MutationServiceProtocol, @unchecked Sendable {
    public var shouldFail = false
    public var modifications: [LKModificationResult] = []

    public init() {}

    public func setAttribute(
        nodeOid: UInt,
        key: String,
        value: String,
        sessionId: String
    ) async throws -> LKModificationResult {
        if shouldFail {
            throw LookinCoreError.attributeModificationFailed(key: key, reason: "Mock failure")
        }
        let result = LKModificationResult(
            nodeOid: nodeOid,
            attributeKey: key,
            previousValue: "<previous>",
            newValue: value,
            success: true
        )
        modifications.append(result)
        return result
    }

    public func invokeMethod(
        nodeOid: UInt,
        selector: String,
        sessionId: String
    ) async throws -> LKConsoleResult {
        if shouldFail {
            throw LookinCoreError.consoleEvalFailed(expression: selector, reason: "Mock failure")
        }
        return LKConsoleResult(
            expression: selector,
            targetOid: nodeOid,
            targetClass: "UIView",
            returnValue: "<void>",
            returnType: .void_,
            success: true
        )
    }

    public func triggerControlTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "control-tap", reason: "Mock failure")
        }
        return LKActionResult(
            action: "control-tap",
            nodeOid: nodeOid,
            targetClass: "UIControl",
            mode: .semantic,
            success: true,
            detail: "Triggered UIControlEventTouchUpInside"
        )
    }

    public func triggerTap(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "tap", reason: "Mock failure")
        }
        return LKActionResult(
            action: "tap",
            nodeOid: nodeOid,
            targetClass: "UIView",
            mode: .semantic,
            success: true,
            detail: "Triggered semantic tap"
        )
    }

    public func triggerLongPress(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "long-press", reason: "Mock failure")
        }
        return LKActionResult(
            action: "long-press",
            nodeOid: nodeOid,
            targetClass: "UIView",
            mode: .semantic,
            success: true,
            detail: "Triggered semantic long press"
        )
    }

    public func triggerDismiss(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKActionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "dismiss", reason: "Mock failure")
        }
        return LKActionResult(
            action: "dismiss",
            nodeOid: nodeOid,
            targetClass: "UIViewController",
            mode: .semantic,
            success: true,
            detail: "Dismissed UIViewController"
        )
    }

    public func inputText(
        nodeOid: UInt,
        text: String,
        sessionId: String
    ) async throws -> LKActionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "input", reason: "Mock failure")
        }
        return LKActionResult(
            action: "input",
            nodeOid: nodeOid,
            targetClass: "UITextInput",
            mode: .semantic,
            success: true,
            detail: "Inserted \(text.count) characters"
        )
    }

    public func inspectGestures(
        nodeOid: UInt,
        sessionId: String
    ) async throws -> LKGestureInspectionResult {
        if shouldFail {
            throw LookinCoreError.actionFailed(action: "gesture-inspect", reason: "Mock failure")
        }
        let rawValue = """
        (
            "<UITapGestureRecognizer: 0x103615470; id = 32; state = Possible; view = <UILabel: 0x10360bed0>; target= <(action=showDetail, target=<UIView_WZB.ViewController 0x103305880>)>>"
        )
        """
        return LKGestureInspectionResult(
            nodeOid: nodeOid,
            targetClass: "UILabel",
            gestures: LKGestureRecognizerParser.parse(rawValue),
            rawValue: rawValue
        )
    }

    public func scrollAnimated(
        nodeOid: UInt,
        targetOffset: CGPoint,
        sessionId: String
    ) async throws -> LKModificationResult {
        if shouldFail {
            throw LookinCoreError.attributeModificationFailed(key: "contentOffset", reason: "Mock failure")
        }
        return LKModificationResult(nodeOid: nodeOid, attributeKey: "contentOffset", previousValue: "0,0", newValue: "\(targetOffset.x),\(targetOffset.y)", success: true)
    }
}
