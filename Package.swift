// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Utouto",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Utouto",
            targets: ["Utouto"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.0"
        ),
    ],
    targets: [
        .target(
            name: "Utouto",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/Utouto",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "UtoutoTests",
            dependencies: ["Utouto"],
            path: "Tests/UtoutoTests"
        ),
    ]
)