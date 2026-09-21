// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "harbor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HarborCLI", targets: ["HarborCLI"]),
        .library(name: "HarborUtils", targets: ["HarborUtils"]),
        .executable(name: "harbor", targets: ["Harbor"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", revision: "a0f43bb719eb3ade9005818e72557ea023af0e60"),
        .package(url: "https://github.com/pakLebah/ANSITerminal", from: "0.0.3"),
        .package(url: "https://github.com/eonist/FileWatcher.git", from: "0.2.3")

    ],
    targets: [
        .executableTarget(
            name: "Harbor",
            dependencies: [
                "HarborCLI",
            ],
            path: "Sources/Harbor"),
        .target(
            name: "HarborCLI",
            dependencies: [
                "HarborUtils"
            ],
            path: "Sources/HarborCLI"),
        .target(
            name: "HarborUtils",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "ANSITerminal",
                "FileWatcher"
            ],
            path: "Sources/HarborUtils"),
        .testTarget(
            name: "HarborUtilsTests",
            dependencies: ["HarborUtils"],
            path: "Tests/HarborUtilsTests"),
        .testTarget(
            name: "HarborCLITests",
            dependencies: ["HarborCLI", "HarborUtils"],
            path: "Tests/HarborCLITests"),
    ]
)
