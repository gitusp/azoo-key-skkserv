// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if canImport(FoundationModels)
let isXcodeVersion26 = true
#else
let isXcodeVersion26 = false
#endif

let xcode26AdditionalTargets: [Target] = [
    .binaryTarget(
        // Note: Xcode 26以降、AzooKeyKanaKanjiConverterのXCFrameworkのbinaryTargetが解決されない問題への対応
        // 詳細は https://github.com/azooKey/azooKey-Desktop/pull/205 を参照
        name: "llama",
        url: "https://github.com/azooKey/llama.cpp/releases/download/b4846/signed-llama.xcframework.zip",
        checksum: "db3b13169df8870375f212e6ac21194225f1c85f7911d595ab64c8c790068e0a"
    )
]

let xcode26AdditionalTargetDependency: [Target.Dependency] = [
    "llama"
]

let package = Package(
    name: "Core",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Core",
            targets: ["Core"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter", from: "0.11.1", traits: ["Zenzai"]),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [
                .product(name: "KanaKanjiConverterModuleWithDefaultDictionary", package: "AzooKeyKanaKanjiConverter"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ] + (isXcodeVersion26 ? xcode26AdditionalTargetDependency : []),
            resources: [
                .copy("zenz-v1.gguf")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
        ),
    ] + (isXcodeVersion26 ? xcode26AdditionalTargets : [])
)
