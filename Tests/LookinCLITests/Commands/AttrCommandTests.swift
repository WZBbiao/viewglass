import XCTest
@testable import LookinCore

final class AttrCommandTests: XCTestCase {

    // MARK: - FlatAttributeValue encoding

    func testRectEncodesAsStructuredJSON() throws {
        let rect = LKRect(x: 20, y: 80, width: 200, height: 44)
        let value = FlatAttributeValue(.rect(rect))

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["x"] as? Int, 20)
        XCTAssertEqual(dict["y"] as? Int, 80)
        XCTAssertEqual(dict["w"] as? Int, 200)
        XCTAssertEqual(dict["h"] as? Int, 44)
    }

    func testRectEncodesWithFractionalCoords() throws {
        let rect = LKRect(x: 10.5, y: 0, width: 100, height: 33.5)
        let value = FlatAttributeValue(.rect(rect))

        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(dict["x"] as? Double, 10.5)
        XCTAssertEqual(dict["y"] as? Int, 0)
        XCTAssertEqual(dict["h"] as? Double, 33.5)
    }

    func testRectStringValuePreservesHumanReadableFormat() {
        let rect = LKRect(x: 20, y: 80, width: 200, height: 44)
        let value = FlatAttributeValue(.rect(rect))
        // stringValue is used by wait attr --equals comparisons
        XCTAssertTrue(value.stringValue.contains("20"))
        XCTAssertTrue(value.stringValue.contains("80"))
        XCTAssertTrue(value.stringValue.contains("200"))
        XCTAssertTrue(value.stringValue.contains("44"))
    }

    func testNumberEncodesAsIntWhenWhole() throws {
        let value = FlatAttributeValue(.number(42.0))
        let data = try JSONEncoder().encode(value)
        let n = try JSONSerialization.jsonObject(with: data) as! Int
        XCTAssertEqual(n, 42)
    }

    func testNumberEncodesAsDoubleWhenFractional() throws {
        let value = FlatAttributeValue(.number(3.14))
        let data = try JSONEncoder().encode(value)
        let n = try JSONSerialization.jsonObject(with: data) as! Double
        XCTAssertEqual(n, 3.14, accuracy: 0.001)
    }

    func testBoolEncodes() throws {
        let t = try JSONEncoder().encode(FlatAttributeValue(.bool(true)))
        let f = try JSONEncoder().encode(FlatAttributeValue(.bool(false)))
        XCTAssertEqual(String(data: t, encoding: .utf8), "true")
        XCTAssertEqual(String(data: f, encoding: .utf8), "false")
    }

    func testNullEncodes() throws {
        let data = try JSONEncoder().encode(FlatAttributeValue(.null))
        XCTAssertEqual(String(data: data, encoding: .utf8), "null")
    }
}
