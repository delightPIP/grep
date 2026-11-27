// swift-tools-version: 6.0
import PackageDescription

// 그렙 공유 코어(ADR-WEB-007, ADR-0010). 웹(wasm)·iOS·Android가 같이 쓴다.
// carti-RIBs-Swift Samples/TodoModular/Shared 구조를 따른다: 피처마다 Interface·Impl·Testing·Tests.
//   GrepCore                     플랫폼이 구현해 주입하는 계약(AuthService, HTTPTransport)과 도메인 값
//   GrepCoreTesting              계약의 가짜 구현과 테스트 도구
//   FeatureLoggedOutInterface    로그인 화면 계약(ViewState·ViewAction·Presentable)
//   FeatureLoggedInInterface     터미널 화면 계약
//   GrepAppRoot                  조립 모듈. 피처 Impl을 아는 곳은 여기 하나다
// Impl은 자기 Interface와 GrepCore만 의존한다. 계약 타깃을 바꾸려면 #31에 먼저 알린다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")

/// 피처 하나의 타깃 4개.
func feature(_ name: String) -> [Target] {
    let path = "Features/\(name)"
    let interface = "Feature\(name)Interface"
    return [
        .target(name: interface, dependencies: [ribs, "GrepCore"], path: "\(path)/Interface"),
        .target(
            name: "Feature\(name)",
            dependencies: [ribs, "GrepCore", .target(name: interface)],
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
                ribs, "GrepCore", "GrepCoreTesting",
                .target(name: interface), .target(name: "Feature\(name)"), .target(name: "Feature\(name)Testing"),
            ],
            path: "\(path)/Tests"
        ),
    ]
}

let features = ["LoggedOut", "LoggedIn"]

/// 플랫폼이 모듈별로 받을 수 있도록 테스트가 아닌 타깃마다 제품을 둔다.
let libraryNames = ["GrepCore", "GrepCoreTesting", "GrepAppRoot"]
    + features.flatMap { ["Feature\($0)Interface", "Feature\($0)", "Feature\($0)Testing"] }

let package = Package(
    name: "GrepCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: libraryNames.map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
    ],
    targets: [
        .target(name: "GrepCore", dependencies: [ribs], path: "Core/Sources"),
        .target(name: "GrepCoreTesting", dependencies: [ribs, "GrepCore"], path: "Core/Testing"),
        .testTarget(name: "GrepCoreTests", dependencies: ["GrepCore"], path: "Core/Tests"),
        .target(
            name: "GrepAppRoot",
            dependencies: [ribs, "GrepCore"] + features.flatMap {
                [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)")]
            },
            path: "App/Sources"
        ),
        .testTarget(
            name: "GrepAppRootTests",
            dependencies: [ribs, "GrepCore", "GrepCoreTesting", "GrepAppRoot"] + features.flatMap {
                [Target.Dependency.target(name: "Feature\($0)Interface"), .target(name: "Feature\($0)Testing")]
            },
            path: "App/Tests"
        ),
    ] + features.flatMap(feature),
    swiftLanguageModes: [.v6]
)
