// swift-tools-version: 6.0
import PackageDescription

// 그렙 웹 앱(Wasm) 패키지(ADR-WEB-007). JavaScriptKit 의존을 공유 코어(../core)에 넣지 않으려고 따로 둔다.
// carti-RIBs-Swift Samples/TodoModular/Web 구조를 따른다.
//   GrepWebSupport     DOM 화면 기반 클래스, 루트 화면
//   FeatureXxxWeb      피처의 웹 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 안다
//   GrepWeb            BridgeJS가 JS로 내보내는 층, 플랫폼 구현(fetch, JS AuthService), 앱 조립
// `@JS` 선언은 GrepWeb 한 타깃에만 둔다.
// 빌드: swift package --swift-sdk swift-6.4.2-RELEASE_wasm js (web/README.md)

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
let ribsWeb: Target.Dependency = .product(name: "RIBsWeb", package: "carti-RIBs-Swift")
let javaScriptKit: Target.Dependency = .product(name: "JavaScriptKit", package: "JavaScriptKit")
let features = ["LoggedOut", "Terminal"]

func core(_ name: String) -> Target.Dependency { .product(name: name, package: "GrepCore") }

let featureTargets: [Target] = features.map { name in
    .target(
        name: "Feature\(name)Web",
        dependencies: [ribs, ribsWeb, javaScriptKit, "GrepWebSupport", core("GrepCore"), core("Feature\(name)Interface")]
    )
}

let package = Package(
    name: "GrepWeb",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(name: "GrepCore", path: "../core"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.63.0"),
    ],
    targets: [
        .target(name: "GrepWebSupport", dependencies: [ribs, ribsWeb, javaScriptKit]),
        .executableTarget(
            name: "GrepWeb",
            dependencies: [
                ribs, ribsWeb, javaScriptKit, "GrepWebSupport",
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
                core("GrepCore"), core("GrepAppRoot"),
            ] + features.flatMap { name -> [Target.Dependency] in
                [.target(name: "Feature\(name)Web"), core("Feature\(name)Interface")]
            },
            swiftSettings: [.enableExperimentalFeature("Extern")],
            plugins: [.plugin(name: "BridgeJS", package: "JavaScriptKit")]
        ),
    ] + featureTargets,
    swiftLanguageModes: [.v6]
)
