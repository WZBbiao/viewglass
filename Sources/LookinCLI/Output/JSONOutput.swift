import Foundation
import LookinCore

public enum JSONOutput {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static func print<T: Encodable>(_ value: T) {
        do {
            let data = try encoder.encode(value)
            if let str = String(data: data, encoding: .utf8) {
                Swift.print(str)
            }
        } catch {
            printError(message: "JSON encoding failed: \(error.localizedDescription)")
        }
    }

    public static func printError(error: LookinCoreError) {
        print(LKErrorResponse(from: error))
    }

    public static func printError(message: String, code: Int32 = 1) {
        print(LKErrorResponse(code: code, message: message))
    }

    public static func printSuccess(message: String) {
        print(SuccessResponse(success: true, message: message))
    }
}

struct SuccessResponse: Codable {
    let success: Bool
    let message: String
}
