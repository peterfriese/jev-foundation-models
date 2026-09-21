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
            path: "Examples/TicketTriageDemo"
        ),
        .testTarget(
            name: "JevFoundationModelsTests",
            dependencies: ["JevFoundationModels"]
        )
    ]
)
