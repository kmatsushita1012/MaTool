// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MaTool",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
        .executable(name: "Backend", targets: ["Backend"]),
        .library(name: "iOSApp", targets: ["iOSApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/kmatsushita1012/NavigationSwipeControl", branch: "main"),
        .package(url: "https://github.com/aws-amplify/amplify-ios.git", exact: "2.50.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.1")
    ],
    targets: [
        // MARK: - Module Target
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "Backend",
            dependencies: ["Shared"],
            path: "Sources/Backend",
            resources: [
                // 必要に応じて JSON / 設定ファイルを追加
                // .process("amplifyconfiguration.json")
            ]
        ),
        .target(
            name: "iOSApp",
            dependencies: [
                "Shared",
                .product(name: "NavigationSwipeControl", package: "NavigationSwipeControl"),
                .product(name: "Amplify", package: "amplify-ios"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-ios"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/iOSApp",
            resources: [
                .process("SupportingFiles"),
            ]
        ),
        // MARK: - Test Target
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"],
            path: "Tests/SharedTests"
        ),
        .testTarget(
            name: "BackendTests",
            dependencies: ["Backend"],
            path: "Tests/BackendTests"
        ),
        .testTarget(
            name: "iOSAppTests",
            dependencies: ["iOSApp"],
            path: "Tests/iOSAppTests"
        )
    ]
)
