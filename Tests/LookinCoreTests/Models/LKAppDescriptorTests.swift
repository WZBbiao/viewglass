import XCTest
@testable import LookinCore

final class LKAppDescriptorTests: XCTestCase {

    func testIdentifier() {
        let app = LKAppDescriptor(
            appName: "TestApp",
            bundleIdentifier: "com.test.app",
            port: 47164
        )
        XCTAssertEqual(app.identifier, "com.test.app@47164")
    }

    func testDeviceType() {
        let sim = LKAppDescriptor(appName: "A", bundleIdentifier: "b", deviceType: .simulator, port: 47164)
        let dev = LKAppDescriptor(appName: "A", bundleIdentifier: "b", deviceType: .device, port: 47175)
        XCTAssertEqual(sim.deviceType, .simulator)
        XCTAssertEqual(dev.deviceType, .device)
    }

    func testCodable() throws {
        let app = LKAppDescriptor(
            appName: "Demo",
            bundleIdentifier: "com.demo",
            appVersion: "1.0",
            deviceName: "iPhone 15",
            deviceType: .device,
            host: "127.0.0.1",
            port: 47164,
            remotePort: 47175,
            deviceIdentifier: "00008101-TEST",
            serverVersion: "1.2.8"
        )

        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(LKAppDescriptor.self, from: data)

        XCTAssertEqual(decoded.appName, "Demo")
        XCTAssertEqual(decoded.bundleIdentifier, "com.demo")
        XCTAssertEqual(decoded.appVersion, "1.0")
        XCTAssertEqual(decoded.deviceName, "iPhone 15")
        XCTAssertEqual(decoded.deviceType, .device)
        XCTAssertEqual(decoded.host, "127.0.0.1")
        XCTAssertEqual(decoded.port, 47164)
        XCTAssertEqual(decoded.remotePort, 47175)
        XCTAssertEqual(decoded.deviceIdentifier, "00008101-TEST")
        XCTAssertEqual(decoded.serverVersion, "1.2.8")
    }

    func testJSONShape() throws {
        let app = LKAppDescriptor(appName: "X", bundleIdentifier: "y", port: 1)
        let data = try JSONEncoder().encode(app)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(dict["appName"])
        XCTAssertNotNil(dict["bundleIdentifier"])
        XCTAssertNotNil(dict["port"])
        XCTAssertNotNil(dict["deviceType"])
        XCTAssertNotNil(dict["host"])
    }

    func testEquality() {
        let a = LKAppDescriptor(appName: "A", bundleIdentifier: "b", port: 1)
        let b = LKAppDescriptor(appName: "A", bundleIdentifier: "b", port: 1)
        let c = LKAppDescriptor(appName: "C", bundleIdentifier: "b", port: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
