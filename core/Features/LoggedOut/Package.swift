// swift-tools-version: 6.0
import PackageDescription

// 로그인 화면 피처(ACC-001). Interface(화면 계약)·Sources(RIB)·Testing(가짜)·Tests.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }

let package = Package(
    name: "FeatureLoggedOut",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["FeatureLoggedOutInterface", "FeatureLoggedOut", "FeatureLoggedOutTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
    ],
    targets: [
        .target(name: "FeatureLoggedOutInterface", dependencies: [ribs, core("GrepCore")], path: "Interface"),
        .target(
            name: "FeatureLoggedOut",
            dependencies: [ribs, core("GrepCore"), "FeatureLoggedOutInterface"],
            path: "Sources"
        ),
        .target(
            name: "FeatureLoggedOutTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureLoggedOutInterface"],
            path: "Testing"
        ),
        .testTarget(
            name: "FeatureLoggedOutTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"),
                "FeatureLoggedOutInterface", "FeatureLoggedOut", "FeatureLoggedOutTesting",
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
