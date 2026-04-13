import Foundation

public struct LKGestureActionInfo: Codable, Sendable, Equatable {
    public let selector: String
    public let targetClass: String?

    public init(selector: String, targetClass: String?) {
        self.selector = selector
        self.targetClass = targetClass
    }
}

public struct LKGestureInfo: Codable, Sendable, Equatable {
    public let recognizerClass: String
    public let recognizerAddress: String?
    public let recognizerId: UInt?
    public let state: String?
    public let viewClass: String?
    public let actions: [LKGestureActionInfo]
    public let rawDescription: String

    public init(
        recognizerClass: String,
        recognizerAddress: String?,
        recognizerId: UInt?,
        state: String?,
        viewClass: String?,
        actions: [LKGestureActionInfo],
        rawDescription: String
    ) {
        self.recognizerClass = recognizerClass
        self.recognizerAddress = recognizerAddress
        self.recognizerId = recognizerId
        self.state = state
        self.viewClass = viewClass
        self.actions = actions
        self.rawDescription = rawDescription
    }
}

public struct LKGestureInspectionResult: Codable, Sendable, Equatable {
    public let nodeOid: UInt
    public let targetClass: String
    public let gestures: [LKGestureInfo]
    public let rawValue: String

    public init(nodeOid: UInt, targetClass: String, gestures: [LKGestureInfo], rawValue: String) {
        self.nodeOid = nodeOid
        self.targetClass = targetClass
        self.gestures = gestures
        self.rawValue = rawValue
    }
}
