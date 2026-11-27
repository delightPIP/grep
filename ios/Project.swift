import ProjectDescription

// 그렙 iOS 앱(ADR-0015). 생성: `ios/`에서 `tuist generate --no-open`.
// 피처 로직은 공유 SwiftPM 패키지(../core)에 있고, 여기에는 플랫폼 포트와 SwiftUI 화면만 둔다.
//   GrepPlatform       HTTPTransport·AuthService·ClipboardPort·FilePort·HistoryStore iOS 구현
//   FeatureXxxUI       순수 SwiftUI 뷰. 값과 콜백만 받는다. SwiftUI에만 의존한다
//   FeatureXxxAdapter  코어 ViewContract 구현과 XxxScreenFactory
//   FeatureXxxExample  피처 하나만 띄우는 Example 앱
//   Grep               GrepAppRoot와 어댑터·플랫폼 포트를 잇는 앱

let deploymentTargets: DeploymentTargets = .iOS("17.0")
let swiftSettings: Settings = .settings(base: ["SWIFT_VERSION": "6.0"])
let bundlePrefix = "com.unwrap.grep"
let features = ["LoggedOut", "Terminal"]

func uiTarget(_ name: String) -> Target {
    .target(
        name: "Feature\(name)UI",
        destinations: .iOS,
        product: .staticFramework,
        bundleId: "\(bundlePrefix).feature.\(name.lowercased()).ui",
        deploymentTargets: deploymentTargets,
        sources: ["Features/\(name)/UI/**"],
        settings: swiftSettings
    )
}

func adapterTarget(_ name: String) -> Target {
    .target(
        name: "Feature\(name)Adapter",
        destinations: .iOS,
        product: .staticFramework,
        bundleId: "\(bundlePrefix).feature.\(name.lowercased()).adapter",
        deploymentTargets: deploymentTargets,
        sources: ["Features/\(name)/Adapter/**"],
        dependencies: [
            .target(name: "Feature\(name)UI"),
            .package(product: "RIBs"),
            .package(product: "RIBsSwiftUI"),
            .package(product: "GrepCore"),
            .package(product: "Feature\(name)Interface"),
        ],
        settings: swiftSettings
    )
}

func exampleTarget(_ name: String) -> Target {
    .target(
        name: "Feature\(name)Example",
        destinations: .iOS,
        product: .app,
        bundleId: "\(bundlePrefix).feature.\(name.lowercased()).example",
        deploymentTargets: deploymentTargets,
        infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
        sources: ["Features/\(name)/Example/**"],
        dependencies: [
            .target(name: "Feature\(name)Adapter"),
            .package(product: "RIBs"),
            .package(product: "RIBsSwiftUI"),
            .package(product: "GrepCore"),
            .package(product: "GrepCoreTesting"),
            .package(product: "Feature\(name)Interface"),
            .package(product: "Feature\(name)"),
            .package(product: "Feature\(name)Testing"),
        ],
        settings: swiftSettings
    )
}

let platformTarget: Target = .target(
    name: "GrepPlatform",
    destinations: .iOS,
    product: .staticFramework,
    bundleId: "\(bundlePrefix).platform",
    deploymentTargets: deploymentTargets,
    sources: ["Platform/Sources/**"],
    dependencies: [.package(product: "GrepCore")],
    settings: swiftSettings
)

let platformTestsTarget: Target = .target(
    name: "GrepPlatformTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundlePrefix).platform.tests",
    deploymentTargets: deploymentTargets,
    sources: ["Platform/Tests/**"],
    dependencies: [
        .target(name: "GrepPlatform"),
        .package(product: "GrepCore"),
    ],
    settings: swiftSettings
)

let loggedInUITarget: Target = uiTarget("LoggedIn")

let loggedInAdapterTarget: Target = .target(
    name: "FeatureLoggedInAdapter",
    destinations: .iOS,
    product: .staticFramework,
    bundleId: "\(bundlePrefix).feature.loggedin.adapter",
    deploymentTargets: deploymentTargets,
    sources: ["Features/LoggedIn/Adapter/**"],
    dependencies: [
        .target(name: "FeatureLoggedInUI"),
        .package(product: "GrepCore"),
    ],
    settings: swiftSettings
)

let loggedInExampleTarget: Target = .target(
    name: "FeatureLoggedInExample",
    destinations: .iOS,
    product: .app,
    bundleId: "\(bundlePrefix).feature.loggedin.example",
    deploymentTargets: deploymentTargets,
    infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
    sources: ["Features/LoggedIn/Example/**"],
    dependencies: [
        .target(name: "FeatureLoggedInAdapter"),
        .target(name: "FeatureLoggedInUI"),
        .target(name: "FeatureTerminalAdapter"),
        .package(product: "RIBs"),
        .package(product: "RIBsSwiftUI"),
        .package(product: "GrepCore"),
        .package(product: "GrepCoreTesting"),
        .package(product: "FeatureTerminalInterface"),
        .package(product: "FeatureTerminal"),
        .package(product: "FeatureTerminalTesting"),
    ],
    settings: swiftSettings
)

let loggedInAdapterTestsTarget: Target = .target(
    name: "FeatureLoggedInAdapterTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundlePrefix).feature.loggedin.adapter.tests",
    deploymentTargets: deploymentTargets,
    sources: ["Features/LoggedIn/Tests/**"],
    dependencies: [
        .target(name: "FeatureLoggedInAdapter"),
        .target(name: "FeatureLoggedInUI"),
        .package(product: "GrepCore"),
    ],
    settings: swiftSettings
)

let terminalAdapterTestsTarget: Target = .target(
    name: "FeatureTerminalAdapterTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "\(bundlePrefix).feature.terminal.adapter.tests",
    deploymentTargets: deploymentTargets,
    sources: ["Features/Terminal/Tests/**"],
    dependencies: [
        .target(name: "FeatureTerminalAdapter"),
        .target(name: "FeatureTerminalUI"),
        .package(product: "GrepCore"),
        .package(product: "FeatureTerminalInterface"),
    ],
    settings: swiftSettings
)

let appDependencies: [TargetDependency] = features.map { .target(name: "Feature\($0)Adapter") } + [
    .target(name: "FeatureLoggedInUI"),
    .target(name: "FeatureLoggedInAdapter"),
    .target(name: "GrepPlatform"),
    .package(product: "RIBs"),
    .package(product: "RIBsSwiftUI"),
    .package(product: "GrepCore"),
    .package(product: "GrepAppRoot"),
    .package(product: "FeatureLoggedOutInterface"),
    .package(product: "FeatureTerminalInterface"),
]

let appInfoPlist: InfoPlist = .extendingDefault(with: [
    "UILaunchScreen": .dictionary([:]),
    // ACC-001 로그인. 값은 Config/App.xcconfig → 커밋하지 않는 Secrets.xcconfig에서 온다.
    "SUPABASE_URL": "$(SUPABASE_URL)",
    "SUPABASE_PUBLISHABLE_KEY": "$(SUPABASE_PUBLISHABLE_KEY)",
    "CFBundleURLTypes": .array([
        .dictionary([
            "CFBundleURLName": .string(bundlePrefix),
            "CFBundleURLSchemes": .array([.string("grep")]),
        ]),
    ]),
])

let appTarget: Target = .target(
    name: "Grep",
    destinations: .iOS,
    product: .app,
    bundleId: bundlePrefix,
    deploymentTargets: deploymentTargets,
    infoPlist: appInfoPlist,
    sources: ["App/Sources/**"],
    dependencies: appDependencies,
    settings: .settings(
        base: ["SWIFT_VERSION": "6.0"],
        configurations: [
            .debug(name: .debug, xcconfig: "Config/App.xcconfig"),
            .release(name: .release, xcconfig: "Config/App.xcconfig"),
        ]
    )
)

let allTargets: [Target] =
    features.map(uiTarget)
    + features.map(adapterTarget)
    + features.map(exampleTarget)
    + [
        loggedInUITarget,
        loggedInAdapterTarget,
        loggedInExampleTarget,
        loggedInAdapterTestsTarget,
        terminalAdapterTestsTarget,
        platformTarget,
        platformTestsTarget,
        appTarget,
    ]

let project = Project(
    name: "Grep",
    packages: [
        .local(path: "../core"),
        .remote(url: "https://github.com/carti1108/carti-RIBs-Swift.git", requirement: .exact("0.1.0")),
    ],
    targets: allTargets
)
