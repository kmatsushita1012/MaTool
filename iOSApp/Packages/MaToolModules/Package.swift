// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "iOSApp",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "iOSShared", targets: ["iOSShared"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "View", targets: ["View"])
    ],
    dependencies: [
        .package(path: "../../../Shared"),
        .package(url: "https://github.com/pointfreeco/sqlite-data.git", from: "1.6.6"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.26.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.9.0"),
        .package(url: "https://github.com/aws-amplify/amplify-ios.git", from: "2.51.5"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.1"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "12.12.0")
    ],
    targets: [
        .target(
            name: "iOSShared",
            dependencies: [
                "Shared",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "Infrastructure",
            dependencies: [
                "iOSShared",
                "Shared",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Amplify", package: "amplify-ios"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-ios"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]
        ),
        .target(
            name: "Application",
            dependencies: [
                "iOSShared",
                "Shared",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "Presentation",
            dependencies: [
                "iOSShared",
                "Application",
                "View",
                "Shared",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "View",
            dependencies: [
                "iOSShared",
                "Shared",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
