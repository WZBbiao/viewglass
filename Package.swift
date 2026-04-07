// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LookinCLI",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "lookin-cli", targets: ["LookinCLI"]),
        .library(name: "LookinCore", targets: ["LookinCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "LookinSharedBridge",
            dependencies: [],
            path: "Sources/LookinSharedBridge",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
        .target(
            name: "LookinCore",
            dependencies: ["LookinSharedBridge"],
            path: "Sources/LookinCore"
        ),
        .executableTarget(
            name: "LookinCLI",
            dependencies: [
                "LookinCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/LookinCLI"
        ),
        .testTarget(
            name: "LookinCoreTests",
            dependencies: ["LookinCore"],
            path: "Tests/LookinCoreTests"
        ),
        .testTarget(
            name: "LookinCLITests",
            dependencies: [
                "LookinCLI",
                "LookinCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Tests/LookinCLITests"
        ),
    ]
)
