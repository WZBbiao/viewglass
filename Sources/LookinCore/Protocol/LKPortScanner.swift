import Foundation

public enum LKPortConstants {
    public static let simulatorPorts: [Int] = [47164, 47165, 47166, 47167, 47168, 47169]
    public static let devicePorts: [Int] = [47175, 47176, 47177, 47178, 47179]
    public static let allPorts: [Int] = simulatorPorts + devicePorts

    public static func isSimulatorPort(_ port: Int) -> Bool {
        simulatorPorts.contains(port)
    }

    public static func isDevicePort(_ port: Int) -> Bool {
        devicePorts.contains(port)
    }
}
