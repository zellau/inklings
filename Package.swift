// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "inklings",
    dependencies: [
        .package(url: "https://github.com/httpswift/swifter.git", branch: "stable"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .target(
            name: "InklingsLib",
            dependencies: []
        ),
        .executableTarget(
            name: "inklings",
            dependencies: [
                "InklingsLib",
                .product(name: "Swifter", package: "swifter"),
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "InklingsTests",
            dependencies: ["InklingsLib"]
        ),
    ]
)