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
        .package(url: "https://github.com/apple/swift-argument-parser.git", branch: "main"),
        .package(url: "https://github.com/pakLebah/ANSITerminal", branch: "master"),
        .package(url: "https://github.com/eonist/FileWatcher.git", branch: "master")

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
    ]
)
