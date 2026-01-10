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
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.7.2"),
        .package(url: "https://github.com/pointfreeco/sqlite-data.git", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "SQLiteData", package: "sqlite-data")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests"
        ),
    ]
)
