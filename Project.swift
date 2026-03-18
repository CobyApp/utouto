import ProjectDescription

// Set your Apple Developer Team ID so `tuist generate` configures automatic signing.
// Find it: Xcode → Signing & Capabilities → Team, or https://developer.apple.com/account#MembershipDetailsCard
let developmentTeamId: String = "3Y8YH8GWMM"

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
            name: "UtoutoAlarmKit",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.coby.utouto.alarmkit",
            deploymentTargets: .iOS("26.1"),
            sources: ["Sources/UtoutoAlarmKit/**/*.swift"],
            settings: .settings(base: [
                "SWIFT_VERSION": "5.9",
                "DEVELOPMENT_TEAM": .string(developmentTeamId),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
        .target(
            name: "Utouto",
            destinations: .iOS,
            product: .app,
            bundleId: "com.coby.utouto",
            deploymentTargets: .iOS("26.1"),
            infoPlist: .file(path: "Sources/Utouto/Info.plist"),
            sources: ["Sources/Utouto/**/*.swift"],
            resources: [
                .glob(pattern: "Sources/Utouto/Resources/en.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/ja.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/ko.lproj/**"),
                .glob(pattern: "Sources/Utouto/Resources/AccentColor.colorset/**"),
            ],
            entitlements: .file(path: "Sources/Utouto/Utouto.entitlements"),
            dependencies: [
                .target(name: "UtoutoAlarmKit"),
                .target(name: "UtoutoWidgetExtension"),
                .package(product: "ComposableArchitecture", type: .runtime),
                .package(product: "Supabase", type: .runtime),
            ],
            settings: .settings(base: [
                "SWIFT_VERSION": "5.9",
                "DEVELOPMENT_TEAM": .string(developmentTeamId),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
        .target(
            name: "UtoutoWidgetExtension",
            destinations: .iOS,
            product: .appExtension,
            bundleId: "com.coby.utouto.widget",
            deploymentTargets: .iOS("26.1"),
            infoPlist: .dictionary([
                "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleDisplayName": "Utouto Alarm",
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                "CFBundleName": "$(PRODUCT_NAME)",
                "CFBundlePackageType": "XPC!",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ]),
            sources: ["Sources/UtoutoWidgetExtension/**/*.swift"],
            dependencies: [.target(name: "UtoutoAlarmKit")],
            settings: .settings(base: [
                "SWIFT_VERSION": "5.9",
                "DEVELOPMENT_TEAM": .string(developmentTeamId),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
        .target(
            name: "UtoutoTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.coby.utouto.tests",
            deploymentTargets: .iOS("26.1"),
            sources: ["Tests/UtoutoTests/**"],
            dependencies: [.target(name: "Utouto")],
            settings: .settings(base: [
                "DEVELOPMENT_TEAM": .string(developmentTeamId),
                "CODE_SIGN_STYLE": "Automatic",
            ])
        ),
    ]
)
