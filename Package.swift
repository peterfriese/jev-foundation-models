// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "jev-foundation-models",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
        .visionOS("27.0")
    ],
    products: [
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
        )
    ],
    targets: [
        .target(
            name: "JevFoundationModels",
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
        .testTarget(
            name: "JevFoundationModelsTests",
            dependencies: ["JevFoundationModels"]
        )
    ]
)
