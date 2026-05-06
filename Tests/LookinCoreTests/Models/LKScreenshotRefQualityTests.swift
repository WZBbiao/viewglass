import XCTest
@testable import LookinCore

final class LKScreenshotRefQualityTests: XCTestCase {
    func testScreenCaptureWithNormalVisibleContentIsUsable() {
        let ref = LKScreenshotRef(
            nodeOid: 0,
            screenshotType: .screen,
            width: 1170,
            height: 2532,
            dataSize: 240_000,
            qualityWarnings: [],
            blackPixelRatio: 0.70,
            nonBlackPixelRatio: 0.12
        )

        XCTAssertTrue(ref.isAgentUsableScreenCapture)
        XCTAssertNil(ref.agentUnusableScreenReason)
    }

    func testMostlyBlackLowContentScreenCaptureIsUnusable() {
        let ref = LKScreenshotRef(
            nodeOid: 0,
            screenshotType: .screen,
            width: 1170,
            height: 2532,
            dataSize: 120_000,
            qualityWarnings: ["mostlyBlack", "lowVisibleContentRatio"],
            blackPixelRatio: 0.96,
            nonBlackPixelRatio: 0.01
        )

        XCTAssertFalse(ref.isAgentUsableScreenCapture)
        XCTAssertTrue(ref.agentUnusableScreenReason?.contains("mostlyBlack") == true)
    }

    func testHighlyCompressedVisibleScreenCaptureIsUsable() {
        let ref = LKScreenshotRef(
            nodeOid: 0,
            screenshotType: .screen,
            width: 1206,
            height: 2622,
            dataSize: 68_864,
            qualityWarnings: [],
            blackPixelRatio: 0.0027,
            nonBlackPixelRatio: 0.9965
        )

        XCTAssertTrue(ref.isAgentUsableScreenCapture)
        XCTAssertNil(ref.agentUnusableScreenReason)
    }

    func testSmallFullScreenCaptureIsUnusable() {
        let ref = LKScreenshotRef(
            nodeOid: 0,
            screenshotType: .screen,
            width: 132,
            height: 132,
            dataSize: 12_000
        )

        XCTAssertFalse(ref.isAgentUsableScreenCapture)
        XCTAssertTrue(ref.agentUnusableScreenReason?.contains("suspiciousSmallDimensions") == true)
    }

    func testNodeScreenshotIsNotRejectedByScreenQualityGate() {
        let ref = LKScreenshotRef(
            nodeOid: 42,
            screenshotType: .solo,
            width: 132,
            height: 132,
            dataSize: 4_000,
            qualityWarnings: ["mostlyBlack", "lowVisibleContentRatio"],
            blackPixelRatio: 0.98,
            nonBlackPixelRatio: 0.01
        )

        XCTAssertTrue(ref.isAgentUsableScreenCapture)
        XCTAssertNil(ref.agentUnusableScreenReason)
    }
}
