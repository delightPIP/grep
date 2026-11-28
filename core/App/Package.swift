// swift-tools-version: 6.0
import PackageDescription

// 조립 모듈(Composition Root). 피처 Impl과 Data 구현을 아는 곳은 여기 하나다.
// 플랫폼(웹·iOS·Android)은 이 패키지의 GrepAppRoot로 앱 트리를 시작한다.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }
let features: [(package: String, name: String)] = [
    ("LoggedOut", "LoggedOut"), ("Terminal", "Terminal"), ("Archive", "Archive"),
    ("Settings", "Settings"), ("LoggedIn", "LoggedIn"),
]
func feature(_ package: String, _ product: String) -> Target.Dependency { .product(name: product, package: package) }

let package = Package(
    name: "GrepAppRoot",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "GrepAppRoot", targets: ["GrepAppRoot"])],
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../Core"),
    ] + features.map { .package(path: "../Features/\($0.package)") },
    targets: [
        .target(
            name: "GrepAppRoot",
            dependencies: [ribs, core("GrepCore"), feature("Archive", "ArchiveData"), feature("Settings", "SettingsData")]
                + features.flatMap {
                    [feature($0.package, "Feature\($0.name)Interface"), feature($0.package, "Feature\($0.name)")]
                },
            path: "Sources"
        ),
        .testTarget(
            name: "GrepAppRootTests",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "GrepAppRoot"]
                + features.flatMap {
                    [feature($0.package, "Feature\($0.name)Interface"), feature($0.package, "Feature\($0.name)Testing")]
                },
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
