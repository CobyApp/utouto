// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Utouto",
    platforms: [
        // Use v17 for SPM/Tuist manifest compatibility (package-description 5.9).
        // App deployment target iOS 26 is set in Project.swift and Xcode project.
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