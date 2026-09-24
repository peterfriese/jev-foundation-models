// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SystemOneFoundationModels",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
        .visionOS("27.0")
    ],
    products: [
        .library(
            name: "SystemOneCore",
            targets: ["SystemOneCore"]
        ),
        .library(
            name: "SystemOneFoundationModels",
            targets: ["SystemOneCore", "LayaFoundationModels", "LayaOnDevice", "JevFoundationModels"]
        ),
        .library(
            name: "LayaFoundationModels",
            targets: ["LayaFoundationModels"]
        ),
        .library(
            name: "LayaOnDevice",
            targets: ["LayaOnDevice"]
        ),
        .library(
            name: "JevFoundationModels",
            targets: ["JevFoundationModels"]
        ),
        .executable(
            name: "ticket-triage-demo",
            targets: ["TicketTriageDemo"]
        ),
        .executable(
            name: "duplicate-article-demo",
            targets: ["DuplicateArticleDemo"]
        ),
        .executable(
            name: "file-organizer-demo",
            targets: ["FileOrganizerDemo"]
        ),
        .executable(
            name: "laya-demo",
            targets: ["LayaDemo"]
        )
    ],
    targets: [
        .target(
            name: "SystemOneCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "LayaFoundationModels",
            dependencies: ["SystemOneCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "LayaOnDevice",
            dependencies: ["SystemOneCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "JevFoundationModels",
            dependencies: ["SystemOneCore"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "TicketTriageDemo",
            dependencies: ["JevFoundationModels"],
            path: "Examples/TicketTriageDemo",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "DuplicateArticleDemo",
            dependencies: ["JevFoundationModels"],
            path: "Examples/DuplicateArticleDemo",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "FileOrganizerDemo",
            dependencies: ["JevFoundationModels"],
            path: "Examples/FileOrganizerDemo",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "LayaDemo",
            dependencies: ["LayaFoundationModels"],
            path: "Examples/LayaDemo",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "JevFoundationModelsTests",
            dependencies: [
                "JevFoundationModels",
                "SystemOneCore",
                "LayaFoundationModels",
                "LayaOnDevice"
            ]
        )
    ]
)
