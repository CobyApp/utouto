import ProjectDescription

let project = Project(
    name: "Utouto",
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.10.0")
        ),
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": "",
            "CODE_SIGN_STYLE": "Automatic",
            "MARKETING_VERSION": "1.0",
            "CURRENT_PROJECT_VERSION": "1",
        ],
        configurations: [
            .debug(name: "Debug", settings: [:], xcconfig: nil),
            .release(name: "Release", settings: [:], xcconfig: nil),
        ]
    ),
    targets: [
        .target(
            name: "Utouto",
            destinations: .iOS,
            product: .app,
            bundleId: "com.example.utouto",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .file(path: "Sources/Utouto/Info.plist"),
            sources: [
                "Sources/Utouto/**",
            ],
            resources: [],
            dependencies: [
                .package(product: "ComposableArchitecture", type: .runtime),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "5.9",
                ]
            )
        ),
        .target(
            name: "UtoutoTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.example.utouto.tests",
            deploymentTargets: .iOS("17.0"),
            sources: [
                "Tests/UtoutoTests/**",
            ],
            dependencies: [
                .target(name: "Utouto"),
            ]
        ),
    ]
)