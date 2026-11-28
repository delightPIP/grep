// swift-tools-version: 6.0
import PackageDescription

// 로그인한 동안의 컨테이너(ADR-0015, ADR-0017). 자식 Terminal·Archive·Settings를 붙이고 둘 사이 알림을 잇는다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }
func terminal(_ name: String) -> Target.Dependency { .product(name: name, package: "Terminal") }
func archive(_ name: String) -> Target.Dependency { .product(name: name, package: "Archive") }
func settings(_ name: String) -> Target.Dependency { .product(name: name, package: "Settings") }

let package = Package(
    name: "FeatureLoggedIn",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["FeatureLoggedInInterface", "FeatureLoggedIn", "FeatureLoggedInTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
        .package(path: "../Terminal"),
        .package(path: "../Archive"),
        .package(path: "../Settings"),
    ],
    targets: [
        .target(name: "FeatureLoggedInInterface", dependencies: [ribs, core("GrepCore")], path: "Interface"),
        .target(
            name: "FeatureLoggedIn",
            dependencies: [
                ribs, core("GrepCore"), "FeatureLoggedInInterface",
                terminal("FeatureTerminalInterface"), archive("FeatureArchiveInterface"), settings("FeatureSettingsInterface"),
            ],
            path: "Sources"
        ),
        .target(
            name: "FeatureLoggedInTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureLoggedInInterface"],
            path: "Testing"
        ),
        .testTarget(
            name: "FeatureLoggedInTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"),
                "FeatureLoggedInInterface", "FeatureLoggedIn", "FeatureLoggedInTesting",
                terminal("FeatureTerminalInterface"), terminal("FeatureTerminal"), terminal("FeatureTerminalTesting"),
                archive("FeatureArchiveInterface"), archive("FeatureArchive"), archive("FeatureArchiveTesting"),
                archive("ArchiveData"),
                settings("FeatureSettingsInterface"), settings("FeatureSettings"), settings("FeatureSettingsTesting"),
                settings("SettingsData"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
