import XCTest
@testable import LookinCore

final class LKRectTests: XCTestCase {

    func testArea() {
        let rect = LKRect(x: 0, y: 0, width: 10, height: 20)
        XCTAssertEqual(rect.area, 200)
    }

    func testIntersects_true() {
        let a = LKRect(x: 0, y: 0, width: 100, height: 100)
        let b = LKRect(x: 50, y: 50, width: 100, height: 100)
        XCTAssertTrue(a.intersects(b))
    }

    func testIntersects_false() {
        let a = LKRect(x: 0, y: 0, width: 100, height: 100)
        let b = LKRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertFalse(a.intersects(b))
    }

    func testIntersects_edgeTouch() {
        let a = LKRect(x: 0, y: 0, width: 100, height: 100)
        let b = LKRect(x: 100, y: 0, width: 100, height: 100)
        XCTAssertFalse(a.intersects(b)) // Touching edges don't intersect
    }

    func testIntersection() {
        let a = LKRect(x: 0, y: 0, width: 100, height: 100)
        let b = LKRect(x: 50, y: 50, width: 100, height: 100)
        let result = a.intersection(b)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.x, 50)
        XCTAssertEqual(result?.y, 50)
        XCTAssertEqual(result?.width, 50)
        XCTAssertEqual(result?.height, 50)
    }

    func testIntersection_none() {
        let a = LKRect(x: 0, y: 0, width: 100, height: 100)
        let b = LKRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertNil(a.intersection(b))
    }

    func testContainsRect() {
        let outer = LKRect(x: 0, y: 0, width: 100, height: 100)
        let inner = LKRect(x: 10, y: 10, width: 50, height: 50)
        let outside = LKRect(x: 50, y: 50, width: 100, height: 100)
        XCTAssertTrue(outer.contains(inner))
        XCTAssertFalse(outer.contains(outside))
    }

    func testContainsPoint() {
        let rect = LKRect(x: 10, y: 10, width: 100, height: 100)
        XCTAssertTrue(rect.contains(point: (x: 50, y: 50)))
        XCTAssertTrue(rect.contains(point: (x: 10, y: 10)))
        XCTAssertTrue(rect.contains(point: (x: 110, y: 110)))
        XCTAssertFalse(rect.contains(point: (x: 9, y: 50)))
        XCTAssertFalse(rect.contains(point: (x: 111, y: 50)))
    }

    func testCodable() throws {
        let rect = LKRect(x: 1.5, y: 2.5, width: 300.0, height: 400.0)
        let data = try JSONEncoder().encode(rect)
        let decoded = try JSONDecoder().decode(LKRect.self, from: data)
        XCTAssertEqual(decoded, rect)
    }
}
