// swift-tools-version: 6.2

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import PackageDescription

let package = Package(
    name: "swift-rtmp-kit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .macCatalyst(.v17)
    ],
    products: [
        .library(
            name: "RTMPKit",
            targets: ["RTMPKit"]
        ),
        .executable(
            name: "rtmp-cli",
            targets: ["RTMPKitCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.77.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.29.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.3")
    ],
    targets: [
        // Core library — depends on NIO for TCP transport
        .target(
            name: "RTMPKit",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ]
        ),

        // CLI commands library — testable independently
        .target(
            name: "RTMPKitCommands",
            dependencies: [
                "RTMPKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),

        // CLI executable — thin entry point only
        .executableTarget(
            name: "RTMPKitCLI",
            dependencies: ["RTMPKitCommands"]
        ),

        // Core library tests
        .testTarget(
            name: "RTMPKitTests",
            dependencies: [
                "RTMPKit",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        ),

        // CLI command tests — SEPARATE from core tests
        .testTarget(
            name: "RTMPKitCommandsTests",
            dependencies: [
                "RTMPKitCommands",
                "RTMPKit",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio")
            ]
        )
    ]
)
