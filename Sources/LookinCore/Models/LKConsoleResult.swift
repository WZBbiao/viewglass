import Foundation

public struct LKConsoleResult: Codable, Equatable, Sendable {
    public let expression: String
    public let targetOid: UInt
    public let targetClass: String
    public let returnValue: String?
    public let returnType: ReturnType
    public let success: Bool
    public let error: String?

    public enum ReturnType: String, Codable, Sendable {
        case void_
        case object
        case string
        case number
        case error
    }

    public init(
        expression: String,
        targetOid: UInt,
        targetClass: String,
        returnValue: String? = nil,
        returnType: ReturnType = .void_,
        success: Bool = true,
        error: String? = nil
    ) {
        self.expression = expression
        self.targetOid = targetOid
        self.targetClass = targetClass
        self.returnValue = returnValue
        self.returnType = returnType
        self.success = success
        self.error = error
    }
}
