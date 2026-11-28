// swift-tools-version: 6.0
import PackageDescription

// 터미널 화면 피처(commands 2절, ADR-0015). Interface(화면 계약)·Sources(RIB)·Testing(가짜)·Tests.

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }

let package = Package(
    name: "FeatureTerminal",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["FeatureTerminalInterface", "FeatureTerminal", "FeatureTerminalTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
    ],
    targets: [
        .target(name: "FeatureTerminalInterface", dependencies: [ribs, core("GrepCore")], path: "Interface"),
        .target(
            name: "FeatureTerminal",
            dependencies: [ribs, core("GrepCore"), core("GrepData"), "FeatureTerminalInterface"],
            path: "Sources"
        ),
        .target(
            name: "FeatureTerminalTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureTerminalInterface"],
            path: "Testing"
        ),
        .testTarget(
            name: "FeatureTerminalTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"), core("GrepData"),
                "FeatureTerminalInterface", "FeatureTerminal", "FeatureTerminalTesting",
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
