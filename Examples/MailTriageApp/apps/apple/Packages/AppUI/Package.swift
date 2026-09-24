// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppUI", targets: ["AppUI"]),
    ],
    dependencies: [
        .package(path: "../AppCore"),
        .package(url: "https://github.com/hmlongco/Factory", from: "3.3.2")
    ],
    targets: [
        .target(
            name: "AppUI",
            dependencies: [
                "AppCore",
                .product(name: "FactoryKit", package: "Factory")
            ]
        ),
        .testTarget(
            name: "AppUITests",
            dependencies: ["AppUI"]
        ),
    ]
)
