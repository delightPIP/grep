// swift-tools-version: 6.0
import PackageDescription

// 그렙 공유 코어(ADR-WEB-007, ADR-0010). 웹(wasm)·iOS·Android가 같이 쓴다.
// carti-RIBs-Swift Samples/TodoModular/Shared 구조를 따른다: 피처마다 Interface·Impl·Testing·Tests.
//   GrepDomain                   도메인 값·규칙·Repository 계약(Core/Domain). 플랫폼·RIBs를 모른다
//   GrepCore                     플랫폼이 구현해 주입하는 계약(AuthService, HTTPTransport). GrepDomain을 다시 내보낸다(Core/Ports)
//   GrepCoreTesting              계약의 가짜 구현과 테스트 도구
//   GrepData                     서버 API 클라이언트(요청을 만들고 응답을 해석한다). 피처 Impl이 같이 쓴다
//   FeatureLoggedOutInterface    로그인 화면 계약(ViewState·ViewAction·Presentable)
//   FeatureTerminalInterface     터미널 화면 계약(상태·동작·뷰 계약)
//   FeatureArchiveInterface      보관함 탭 계약(#168, ARC-007)
//   FeatureSettingsInterface     설정 탭 계약(#168)
//   FeatureLoggedInInterface     로그인한 동안의 컨테이너 계약. 자식 Terminal·Archive·Settings를 붙인다(ADR-0015)
//   GrepAppRoot                  조립 모듈. 피처 Impl을 아는 곳은 여기 하나다
// Impl은 자기 Interface와 GrepCore, 그리고 붙이는 자식의 Interface만 의존한다. 계약 타깃을 바꾸려면 #31에 먼저 알린다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")

/// 피처 하나의 타깃 4개. `children`은 이 피처가 붙이는 자식 피처다. Impl은 자식의 Interface만 알고, 테스트는 자식 Impl까지 붙여 본다.
func feature(_ name: String, children: [String] = []) -> [Target] {
    let path = "Features/\(name)"
    let interface = "Feature\(name)Interface"
    let childInterfaces = children.map { Target.Dependency.target(name: "Feature\($0)Interface") }
    let childImpls = children.flatMap {
        [Target.Dependency.target(name: "Feature\($0)"), .target(name: "Feature\($0)Testing")]
    }
    return [
        .target(name: interface, dependencies: [ribs, "GrepCore"], path: "\(path)/Interface"),
        .target(
            name: "Feature\(name)",
            dependencies: [ribs, "GrepCore", "GrepData", .target(name: interface)] + childInterfaces,
            path: "\(path)/Sources"
        ),
        .target(
            name: "Feature\(name)Testing",
            dependencies: [ribs, "GrepCore", "GrepCoreTesting", .target(name: interface)],
            path: "\(path)/Testing"
        ),
        .testTarget(
            name: "Feature\(name)Tests",
            dependencies: [
                ribs, "GrepCore", "GrepCoreTesting", "GrepData",
                .target(name: interface), .target(name: "Feature\(name)"), .target(name: "Feature\(name)Testing"),
            ] + childInterfaces + childImpls,
            path: "\(path)/Tests"
        ),
    ]
}

let features = ["LoggedOut", "Terminal", "Archive", "Settings", "LoggedIn"]
/// 피처가 붙이는 자식 피처.
let children: [String: [String]] = ["LoggedIn": ["Terminal", "Archive", "Settings"]]

let featureTargets: [Target] = features.flatMap { (name: String) -> [Target] in
    feature(name, children: children[name] ?? [])
}

/// 플랫폼이 모듈별로 받을 수 있도록 테스트가 아닌 타깃마다 제품을 둔다.
let libraryNames = ["GrepDomain", "GrepCore", "GrepCoreTesting", "GrepData", "GrepAppRoot"]
    + features.flatMap { ["Feature\($0)Interface", "Feature\($0)", "Feature\($0)Testing"] }

let appRootDependencies: [Target.Dependency] = [ribs, "GrepCore"] + features.flatMap {
    [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)")]
}

let appRootTestDependencies: [Target.Dependency] = [ribs, "GrepCore", "GrepCoreTesting", "GrepAppRoot"]
    + features.flatMap {
        [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)Testing")]
    }

let baseTargets: [Target] = [
    .target(name: "GrepDomain", path: "Core/Domain/Sources"),
    .testTarget(name: "GrepDomainTests", dependencies: ["GrepDomain"], path: "Core/Domain/Tests"),
    .target(name: "GrepCore", dependencies: [ribs, "GrepDomain"], path: "Core/Ports/Sources"),
    .target(name: "GrepCoreTesting", dependencies: [ribs, "GrepCore"], path: "Core/Testing"),
    .target(name: "GrepData", dependencies: ["GrepCore"], path: "Core/Data/Sources"),
    .testTarget(name: "GrepCoreTests", dependencies: ["GrepCore"], path: "Core/Tests"),
    .target(name: "GrepAppRoot", dependencies: appRootDependencies, path: "App/Sources"),
    .testTarget(name: "GrepAppRootTests", dependencies: appRootTestDependencies, path: "App/Tests"),
]

let allTargets: [Target] = baseTargets + featureTargets
let packageProducts: [Product] = libraryNames.map { .library(name: $0, targets: [$0]) }

let package = Package(
    name: "GrepCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: packageProducts,
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
    ],
    targets: allTargets,
    swiftLanguageModes: [.v6]
)
