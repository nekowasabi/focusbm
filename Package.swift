// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "focusbm",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "FocusBMLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/FocusBMLib",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "focusbm",
            dependencies: ["FocusBMLib"],
            path: "Sources/focusbm",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FocusBMApp",
            dependencies: ["FocusBMLib"],
            path: "Sources/FocusBMApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "focusbmTests",
            dependencies: [
                "FocusBMLib",
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Tests/focusbmTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
