// swift-tools-version: 6.0
import PackageDescription

// 그렙 공유 코어(ADR-WEB-007, ADR-0010). 웹(wasm)·iOS·Android가 같이 쓴다.
// carti-RIBs-Swift Samples/TodoModular/Shared 구조를 따른다: 피처마다 Interface·Impl·Testing·Tests.
//   GrepCore                     플랫폼이 구현해 주입하는 계약(AuthService, HTTPTransport)과 도메인 값
//   FeatureLoggedOutInterface    로그인 화면 계약(ViewState·ViewAction·Presentable)
//   FeatureLoggedInInterface     터미널 화면 계약
// 피처 구현·Testing·앱 루트 타깃은 #31 B 갈래가 추가한다. 계약 타깃을 바꾸려면 #31에 먼저 알린다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")

let package = Package(
    name: "GrepCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "GrepCore", targets: ["GrepCore"]),
        .library(name: "FeatureLoggedOutInterface", targets: ["FeatureLoggedOutInterface"]),
        .library(name: "FeatureLoggedInInterface", targets: ["FeatureLoggedInInterface"]),
    ],
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
    ],
    targets: [
        .target(name: "GrepCore", dependencies: [ribs], path: "Core/Sources"),
        .target(
            name: "FeatureLoggedOutInterface",
            dependencies: [ribs, "GrepCore"],
            path: "Features/LoggedOut/Interface"
        ),
        .target(
            name: "FeatureLoggedInInterface",
            dependencies: [ribs, "GrepCore"],
            path: "Features/LoggedIn/Interface"
        ),
        .testTarget(name: "GrepCoreTests", dependencies: ["GrepCore"], path: "Core/Tests"),
    ],
    swiftLanguageModes: [.v6]
)
