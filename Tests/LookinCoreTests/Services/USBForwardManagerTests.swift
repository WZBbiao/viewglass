import XCTest
@testable import LookinCore

final class USBForwardManagerTests: XCTestCase {
    func testSuggestedLocalPortIsStableAcrossCalls() {
        let manager = USBForwardManager(directory: NSTemporaryDirectory() + "viewglass-usb-\(UUID().uuidString)")
        let first = manager.suggestedLocalPort(deviceIdentifier: "00008101-00166D911ED2001E", remotePort: 47175)
        let second = manager.suggestedLocalPort(deviceIdentifier: "00008101-00166D911ED2001E", remotePort: 47175)

        XCTAssertEqual(first, second)
    }

    func testSuggestedLocalPortChangesWithRemotePort() {
        let manager = USBForwardManager(directory: NSTemporaryDirectory() + "viewglass-usb-\(UUID().uuidString)")
        let base = manager.suggestedLocalPort(deviceIdentifier: "device-a", remotePort: 47175)
        let next = manager.suggestedLocalPort(deviceIdentifier: "device-a", remotePort: 47176)

        XCTAssertEqual(next, base + 1)
    }

    func testSuggestedLocalPortChangesWithDeviceIdentifier() {
        let manager = USBForwardManager(directory: NSTemporaryDirectory() + "viewglass-usb-\(UUID().uuidString)")
        let first = manager.suggestedLocalPort(deviceIdentifier: "device-a", remotePort: 47175)
        let second = manager.suggestedLocalPort(deviceIdentifier: "device-b", remotePort: 47175)

        XCTAssertNotEqual(first, second)
    }
}
