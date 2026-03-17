import ProjectDescription

let project = Project(
    name: "Utouto",
    options: .options(
        defaultKnownRegions: ["en", "ja", "ko"],
        developmentRegion: "en"
    ),
    packages: [
        .remote(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            requirement: .upToNextMajor(from: "1.10.0")
        ),
        .remote(
            url: "https://github.com/supabase/supabase-swift",
            requirement: .upToNextMajor(from: "2.0.0")
        ),
    ],
    settings: .settings(
        base: [
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
            deploymentTargets: .iOS("26.1"),
            infoPlist: .file(path: "Sources/Utouto/Info.plist"),
            sources: ["Sources/Utouto/**"],
            resources: [
                .glob(pattern: "Sources/Utouto/Resources/en.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/ja.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/ko.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/AccentColor.colorset/**"),
            ],
            dependencies: [
                .package(product: "ComposableArchitecture", type: .runtime),
                .package(product: "Supabase", type: .runtime),
            ],
            settings: .settings(base: ["SWIFT_VERSION": "5.9"])
        ),
        .target(
            name: "UtoutoTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.example.utouto.tests",
            deploymentTargets: .iOS("26.1"),
            sources: ["Tests/UtoutoTests/**"],
            dependencies: [.target(name: "Utouto")]
        ),
    ]
)
