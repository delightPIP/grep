// swift-tools-version: 6.0
import PackageDescription

// 터미널 화면 피처(commands 2절, ADR-0015, ADR-0017). MusicSearch `Features/<피처>`와 같은 배치.
//   Shared/Domain      TerminalDomain      줄·상태 값, 명령 해석기
//   Shared/Data        TerminalData        터미널만 쓰는 서버 API(넘기기·가져오기·이벤트·샘플·고치기·자세히 보기)
//   Shared/CommandKit  TerminalCommandKit  명령 모듈 계약(TerminalContext·TerminalCommand)과 공통 부모
//   Terminal<명령>     TerminalSave·TerminalBrowse·TerminalHandoff·TerminalCollections·TerminalConnections 명령 모듈
//   TerminalMain       FeatureTerminalInterface(화면 계약) · FeatureTerminal(RIB) · FeatureTerminalTesting(가짜) · 테스트

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }

let package = Package(
    name: "FeatureTerminal",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["TerminalDomain", "FeatureTerminalInterface", "FeatureTerminal", "FeatureTerminalTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
    ],
    targets: [
        .target(name: "TerminalDomain", dependencies: [core("GrepDomain")], path: "Shared/Domain/Sources"),
        .target(
            name: "TerminalData",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain"],
            path: "Shared/Data/Sources"
        ),
        .target(
            name: "TerminalCommandKit",
            dependencies: [core("GrepCore"), "TerminalDomain"],
            path: "Shared/CommandKit/Sources"
        ),
        .target(
            name: "TerminalBrowse",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalData", "TerminalCommandKit"],
            path: "TerminalBrowse/Sources"
        ),
        .target(
            name: "TerminalCollections",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalData", "TerminalCommandKit"],
            path: "TerminalCollections/Sources"
        ),
        .target(
            name: "TerminalHandoff",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalData", "TerminalCommandKit"],
            path: "TerminalHandoff/Sources"
        ),
        .target(
            name: "TerminalSave",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalData", "TerminalCommandKit"],
            path: "TerminalSave/Sources"
        ),
        .target(
            name: "TerminalConnections",
            dependencies: [core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalCommandKit"],
            path: "TerminalConnections/Sources"
        ),
        .target(
            name: "FeatureTerminalInterface",
            dependencies: [ribs, core("GrepCore"), "TerminalDomain"],
            path: "TerminalMain/Interface"
        ),
        .target(
            name: "FeatureTerminal",
            dependencies: [
                ribs, core("GrepCore"), core("GrepData"), "TerminalDomain", "TerminalCommandKit", "FeatureTerminalInterface",
                "TerminalBrowse", "TerminalCollections", "TerminalConnections", "TerminalHandoff", "TerminalSave",
            ],
            path: "TerminalMain/Sources"
        ),
        .target(
            name: "FeatureTerminalTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureTerminalInterface"],
            path: "TerminalMain/Testing"
        ),
        .testTarget(
            name: "FeatureTerminalTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"), core("GrepData"),
                "TerminalDomain", "FeatureTerminalInterface", "FeatureTerminal", "FeatureTerminalTesting",
            ],
            path: "TerminalMain/Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
