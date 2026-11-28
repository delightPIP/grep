// swift-tools-version: 6.0
import PackageDescription

// 공유 코어의 바닥 패키지(ADR-WEB-007, ADR-0017). 피처 패키지가 모두 이 패키지를 의존한다.
//   GrepDomain       도메인 값·규칙·Repository 계약. 플랫폼·RIBs를 모른다(Domain/)
//   GrepCore         플랫폼이 구현해 주입하는 계약(인증·HTTP·클립보드·파일·기록). GrepDomain을 다시 내보낸다(Ports/)
//   GrepData         서버 API 클라이언트와 Repository 구현(Data/)
//   GrepCoreTesting  계약의 가짜 구현과 테스트 도구(Testing/)

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")

let package = Package(
    name: "GrepCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["GrepDomain", "GrepCore", "GrepData", "GrepCoreTesting"].map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
    ],
    targets: [
        .target(name: "GrepDomain", path: "Domain/Sources"),
        .testTarget(name: "GrepDomainTests", dependencies: ["GrepDomain"], path: "Domain/Tests"),
        .target(name: "GrepCore", dependencies: [ribs, "GrepDomain"], path: "Ports/Sources"),
        .testTarget(name: "GrepCoreTests", dependencies: ["GrepCore"], path: "Tests"),
        .target(name: "GrepData", dependencies: ["GrepCore"], path: "Data/Sources"),
        .target(name: "GrepCoreTesting", dependencies: [ribs, "GrepCore"], path: "Testing"),
    ],
    swiftLanguageModes: [.v6]
)
