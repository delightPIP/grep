// swift-tools-version: 6.0
import PackageDescription

// 설정 탭 피처(#168). MusicSearch `Features/<피처>`와 같은 배치.
//   Shared/Domain  SettingsDomain   계정 값과 SettingsRepository 계약
//   Shared/Data    SettingsData     SettingsRepository 구현(`/me`, `/connections`)
//   SettingsMain   FeatureSettingsInterface(화면 계약) · FeatureSettings(RIB) · FeatureSettingsTesting(가짜) · 테스트

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }

let package = Package(
    name: "FeatureSettings",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["SettingsDomain", "SettingsData", "FeatureSettingsInterface", "FeatureSettings", "FeatureSettingsTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
    ],
    targets: [
        .target(name: "SettingsDomain", dependencies: [core("GrepDomain")], path: "Shared/Domain/Sources"),
        .target(
            name: "SettingsData",
            dependencies: ["SettingsDomain", core("GrepCore"), core("GrepData")],
            path: "Shared/Data/Sources"
        ),
        .target(
            name: "FeatureSettingsInterface",
            dependencies: [ribs, core("GrepCore"), "SettingsDomain"],
            path: "SettingsMain/Interface"
        ),
        .target(
            name: "FeatureSettings",
            dependencies: [ribs, core("GrepCore"), "SettingsDomain", "FeatureSettingsInterface"],
            path: "SettingsMain/Sources"
        ),
        .target(
            name: "FeatureSettingsTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureSettingsInterface"],
            path: "SettingsMain/Testing"
        ),
        .testTarget(
            name: "FeatureSettingsTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"),
                "SettingsDomain", "SettingsData", "FeatureSettingsInterface", "FeatureSettings", "FeatureSettingsTesting",
            ],
            path: "SettingsMain/Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
