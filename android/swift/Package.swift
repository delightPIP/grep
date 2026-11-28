// swift-tools-version: 6.1
import PackageDescription

// 그렙 Android 앱에 넣을 Swift 라이브러리(libGrepBridge.so) 하나(ADR-0015).
// swift-java의 SwiftJava는 동적 라이브러리 전용이라 피처별 Android 화면 모듈은 SwiftPM 타깃으로 나누고 한 .so로 링크한다.
//   GrepAndroidSupport       화면 기반 클래스, 화면 등록부, 루트·자리표시 화면
//   FeatureXxxAndroid        피처의 Android 화면(뷰 계약 구현)과 뷰 팩토리. 자기 Interface만 안다
//   GrepAndroid              전체 앱과 피처별 단독 실행(demo) 조립, 플랫폼 포트 어댑터. 호스트에서 테스트한다
//   GrepBridge               swift-java가 Java 바인딩을 만드는 층과 JNI 진입점
// 빌드에 JAVA_HOME(JDK 21)과 `swift build --disable-sandbox`가 필요하다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
let ribsAndroid: Target.Dependency = .product(name: "RIBsAndroid", package: "carti-RIBs-Swift")
let features = ["LoggedOut", "Terminal"]

/// 공유 코어(`../core`)는 패키지 여러 개다(ADR-0017). 제품 이름으로 그 제품이 든 패키지를 찾는다.
let coreFeatures = ["LoggedOut", "Terminal", "Archive", "Settings", "LoggedIn"]
func corePackage(of product: String) -> String {
    if product == "GrepAppRoot" { return "App" }
    if let feature = coreFeatures.first(where: { product.hasPrefix("Feature\($0)") || product.hasPrefix($0) }) {
        return feature
    }
    return "Core"
}
func core(_ name: String) -> Target.Dependency { .product(name: name, package: corePackage(of: name)) }

let featureTargets: [Target] = features.map { name in
    .target(
        name: "Feature\(name)Android",
        dependencies: [ribs, ribsAndroid, "GrepAndroidSupport", core("GrepCore"), core("Feature\(name)Interface")]
    )
}

let package = Package(
    name: "GrepAndroidSwift",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GrepBridge", type: .dynamic, targets: ["GrepBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../core/Core"),
        .package(path: "../../core/App"),
        .package(url: "https://github.com/swiftlang/swift-java", exact: "0.7.0"),
    ] + coreFeatures.map { .package(path: "../../core/Features/\($0)") },
    targets: [
        .target(name: "GrepAndroidSupport", dependencies: [ribs, ribsAndroid]),
        .target(
            name: "GrepAndroid",
            dependencies: [
                ribs, ribsAndroid, "GrepAndroidSupport",
                core("GrepCore"), core("GrepCoreTesting"), core("GrepData"), core("GrepAppRoot"),
                core("FeatureLoggedInInterface"), core("FeatureLoggedIn"),
            ]
                + features.flatMap { name -> [Target.Dependency] in
                    [
                        .target(name: "Feature\(name)Android"),
                        core("Feature\(name)Interface"), core("Feature\(name)"), core("Feature\(name)Testing"),
                    ]
                }
        ),
        .target(
            name: "GrepBridge",
            dependencies: [
                "GrepAndroid", "GrepAndroidSupport", ribsAndroid, core("GrepCore"),
                .product(name: "SwiftJava", package: "swift-java"),
            ] + features.map { .target(name: "Feature\($0)Android") },
            exclude: ["swift-java.config"],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
        .testTarget(
            name: "GrepAndroidTests",
            dependencies: ["GrepAndroid", "GrepAndroidSupport", ribs, core("GrepCore"), core("GrepCoreTesting"), core("FeatureTerminalInterface")]
                + features.map { .target(name: "Feature\($0)Android") }
        ),
    ] + featureTargets,
    swiftLanguageModes: [.v6]
)
