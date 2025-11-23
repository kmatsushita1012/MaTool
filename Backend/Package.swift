// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "matool-backend",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Backend", targets: ["Backend"]),
    ],
    dependencies: [
        .package(path: "../Shared"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.5.18"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "1.2.3"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.7.2"),
        .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Backend",
            dependencies: [
                "Shared",
                .product(name: "AWSDynamoDB", package: "aws-sdk-swift"),
                .product(name: "AWSCognitoIdentityProvider", package: "aws-sdk-swift"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "SwiftDotenv", package: "swift-dotenv")
            ],
            path: "Sources",
            resources: [
                .copy("../.env")
            ]
        ),
        .testTarget(
            name: "BackendTests",
            dependencies: ["Backend"],
            path: "Tests"
        ),
    ]
)
