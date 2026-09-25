// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
        .executable(name: "BenchmarkCLI", targets: ["BenchmarkCLI"]),
    ],
    dependencies: [
        .package(path: "../../../../../.."),
        .package(url: "https://github.com/hmlongco/Factory", from: "3.3.2")
    ],
    targets: [
        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "SystemOneCore", package: "system-one-laya"),
                .product(name: "LayaFoundationModels", package: "system-one-laya"),
                .product(name: "JevFoundationModels", package: "system-one-laya"),
                .product(name: "LayaOnDevice", package: "system-one-laya"),
                .product(name: "FactoryKit", package: "Factory")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "BenchmarkCLI",
            dependencies: [
                "AppCore",
                .product(name: "FactoryKit", package: "Factory")
            ],
            path: "Sources/BenchmarkCLI"
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"]
        ),
    ]
)
