import XCTest
@testable import LookinCore

final class LKErrorTests: XCTestCase {

    func testExitCodes() {
        XCTAssertEqual(LookinCoreError.noAppsFound.exitCode, 10)
        XCTAssertEqual(LookinCoreError.appNotFound(identifier: "x").exitCode, 11)
        XCTAssertEqual(LookinCoreError.sessionNotConnected.exitCode, 20)
        XCTAssertEqual(LookinCoreError.connectionFailed(host: "h", port: 1).exitCode, 21)
        XCTAssertEqual(LookinCoreError.connectionTimeout.exitCode, 22)
        XCTAssertEqual(LookinCoreError.nodeNotFound(oid: 1).exitCode, 30)
        XCTAssertEqual(LookinCoreError.querySyntaxError(expression: "e", reason: "r").exitCode, 31)
        XCTAssertEqual(LookinCoreError.screenshotFailed(reason: "r").exitCode, 40)
        XCTAssertEqual(LookinCoreError.attributeModificationFailed(key: "k", reason: "r").exitCode, 50)
        XCTAssertEqual(LookinCoreError.consoleEvalFailed(expression: "e", reason: "r").exitCode, 51)
        XCTAssertEqual(LookinCoreError.exportFailed(reason: "r").exitCode, 60)
        XCTAssertEqual(LookinCoreError.serverVersionMismatch(server: "s", client: "c").exitCode, 70)
        XCTAssertEqual(LookinCoreError.appInBackground.exitCode, 71)
        XCTAssertEqual(LookinCoreError.protocolError(reason: "r").exitCode, 72)
        XCTAssertEqual(LookinCoreError.fileNotFound(path: "p").exitCode, 80)
        XCTAssertEqual(LookinCoreError.invalidFileFormat(reason: "r").exitCode, 81)
    }

    func testErrorDescriptions() {
        XCTAssertNotNil(LookinCoreError.noAppsFound.errorDescription)
        XCTAssertNotNil(LookinCoreError.sessionNotConnected.errorDescription)
        XCTAssertNotNil(LookinCoreError.nodeNotFound(oid: 1).errorDescription)
    }

    func testErrorResponseCodable() throws {
        let response = LKErrorResponse(from: .noAppsFound)
        XCTAssertTrue(response.error)
        XCTAssertEqual(response.code, 10)
        XCTAssertFalse(response.message.isEmpty)

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(LKErrorResponse.self, from: data)
        XCTAssertEqual(decoded.code, response.code)
        XCTAssertEqual(decoded.message, response.message)
    }
}
