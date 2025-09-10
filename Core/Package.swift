// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
            ],
            resources: [
                .copy("zenz-v1.gguf")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ],
        ),
    ]
)
