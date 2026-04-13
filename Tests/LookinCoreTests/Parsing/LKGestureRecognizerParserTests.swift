import XCTest
@testable import LookinCore

final class LKGestureRecognizerParserTests: XCTestCase {
    func testParseTapRecognizerDescription() {
        let raw = """
        (
            "<UITapGestureRecognizer: 0x103615470; id = 32; state = Possible; view = <UILabel: 0x10360bed0>; target= <(action=showDetail, target=<UIView_WZB.ViewController 0x103305880>)>>"
        )
        """

        let gestures = LKGestureRecognizerParser.parse(raw)
        XCTAssertEqual(gestures.count, 1)
        XCTAssertEqual(gestures[0].recognizerClass, "UITapGestureRecognizer")
        XCTAssertEqual(gestures[0].recognizerId, 32)
        XCTAssertEqual(gestures[0].state, "Possible")
        XCTAssertEqual(gestures[0].viewClass, "UILabel")
        XCTAssertEqual(gestures[0].actions.first?.selector, "showDetail")
        XCTAssertEqual(gestures[0].actions.first?.targetClass, "UIView_WZB.ViewController")
    }

    func testParseEmptyRecognizerList() {
        XCTAssertTrue(LKGestureRecognizerParser.parse("(\n)\n").isEmpty)
    }
}
