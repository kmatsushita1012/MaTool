// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "matool-shared",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Shared",
            path: "Sources"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests"
        ),
    ]
)
