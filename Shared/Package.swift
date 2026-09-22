// swift-tools-version: 6.2

import PackageDescription

let sharedDependencies: [Package.Dependency]
let sharedTargetDependencies: [Target.Dependency]

#if os(Linux)
sharedDependencies = [
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.7.2"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries.git", from: "0.27.0")
]
sharedTargetDependencies = [
    .product(name: "CasePaths", package: "swift-case-paths"),
    .product(name: "StructuredQueries", package: "swift-structured-queries")
]
#else
sharedDependencies = [
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.7.2"),
    .package(url: "https://github.com/pointfreeco/sqlite-data.git", from: "1.5.0")
]
sharedTargetDependencies = [
    .product(name: "CasePaths", package: "swift-case-paths"),
    .product(name: "SQLiteData", package: "sqlite-data")
]
#endif

let package = Package(
    name: "matool-shared",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: sharedDependencies,
    targets: [
        .target(
            name: "Shared",
            dependencies: sharedTargetDependencies,
            path: "Sources"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests"
        ),
    ]
)
