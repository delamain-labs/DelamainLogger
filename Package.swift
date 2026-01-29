// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DelamainLogger",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DelamainLogger",
            targets: ["DelamainLogger"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        .target(
            name: "DelamainLogger",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DelamainLoggerTests",
            dependencies: ["DelamainLogger"]
        )
    ]
)
