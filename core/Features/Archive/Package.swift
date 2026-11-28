// swift-tools-version: 6.0
import PackageDescription

// 보관함 탭 피처(#168, ARC-007). MusicSearch `Features/Archive`와 같은 배치.
//   Shared/Domain  ArchiveDomain   보관함 값(거르기·자동 묶음)과 ArchiveRepository 계약
//   Shared/Data    ArchiveData     ArchiveRepository 구현(서버 API, 거르기 → 요청)
//   ArchiveMain    FeatureArchiveInterface(화면 계약) · FeatureArchive(RIB) · FeatureArchiveTesting(가짜) · 테스트

let ribs: Target.Dependency = .product(name: "RIBs", package: "carti-RIBs-Swift")
func core(_ name: String) -> Target.Dependency { .product(name: name, package: "Core") }

let package = Package(
    name: "FeatureArchive",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: ["ArchiveDomain", "ArchiveData", "FeatureArchiveInterface", "FeatureArchive", "FeatureArchiveTesting"].map {
        .library(name: $0, targets: [$0])
    },
    dependencies: [
        .package(url: "https://github.com/carti1108/carti-RIBs-Swift.git", exact: "0.1.0"),
        .package(path: "../../Core"),
    ],
    targets: [
        .target(name: "ArchiveDomain", dependencies: [core("GrepDomain")], path: "Shared/Domain/Sources"),
        .target(
            name: "ArchiveData",
            dependencies: ["ArchiveDomain", core("GrepCore"), core("GrepData")],
            path: "Shared/Data/Sources"
        ),
        .testTarget(
            name: "ArchiveDataTests",
            dependencies: ["ArchiveData", "ArchiveDomain", core("GrepCore")],
            path: "Shared/Data/Tests"
        ),
        .target(
            name: "FeatureArchiveInterface",
            dependencies: [ribs, core("GrepCore"), "ArchiveDomain"],
            path: "ArchiveMain/Interface"
        ),
        .target(
            name: "FeatureArchive",
            dependencies: [ribs, core("GrepCore"), "ArchiveDomain", "FeatureArchiveInterface"],
            path: "ArchiveMain/Sources"
        ),
        .target(
            name: "FeatureArchiveTesting",
            dependencies: [ribs, core("GrepCore"), core("GrepCoreTesting"), "FeatureArchiveInterface"],
            path: "ArchiveMain/Testing"
        ),
        .testTarget(
            name: "FeatureArchiveTests",
            dependencies: [
                ribs, core("GrepCore"), core("GrepCoreTesting"),
                "ArchiveDomain", "ArchiveData", "FeatureArchiveInterface", "FeatureArchive", "FeatureArchiveTesting",
            ],
            path: "ArchiveMain/Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
