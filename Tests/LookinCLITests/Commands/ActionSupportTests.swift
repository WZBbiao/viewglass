import XCTest
@testable import LookinCLI
@testable import LookinCore

final class ActionSupportTests: XCTestCase {
    func testParseCGPointAcceptsCommaSeparatedPair() throws {
        let point = try parseCGPoint(argument: "12,34", label: "scroll")
        XCTAssertEqual(point.x, 12)
        XCTAssertEqual(point.y, 34)
    }

    func testParseCGPointRejectsInvalidInput() {
        XCTAssertThrowsError(try parseCGPoint(argument: "12", label: "scroll")) { error in
            guard case LookinCoreError.actionFailed(let action, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(action, "scroll")
        }
    }
}
