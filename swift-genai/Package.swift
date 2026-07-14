// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-genai",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GoogleGenerativeAI",
            targets: ["GeminiAPIClient"]
        ),
        .library(
            name: "InternalGeminiDataModels",
            targets: ["InternalGoogleAIDataModels", "InternalAgentPlatformDataModels", "InternalSharedDataModels"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GeminiAPIClient",
            dependencies: [
              "InternalGoogleAIDataModels",
              "InternalAgentPlatformDataModels",
              "InternalSharedDataModels"
            ],
            swiftSettings: [
              .swiftLanguageMode(.v6),
              .enableUpcomingFeature("InternalImportsByDefault"),
              .enableUpcomingFeature("InferIsolatedConformances"),
              .enableUpcomingFeature("MemberImportVisibility"),
              .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
              .enableUpcomingFeature("NonescapableTypes")
            ],
        ),
        .testTarget(
            name: "GeminiAPIClientTests",
            dependencies: ["GeminiAPIClient"],
            swiftSettings: [
              .swiftLanguageMode(.v6),
              .enableUpcomingFeature("InternalImportsByDefault"),
              .enableUpcomingFeature("InferIsolatedConformances"),
              .enableUpcomingFeature("MemberImportVisibility"),
              .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
              .enableUpcomingFeature("NonescapableTypes")
            ],
        ),
        .target(
            name: "InternalSharedDataModels",
            swiftSettings: [
              .swiftLanguageMode(.v6),
              .enableUpcomingFeature("InternalImportsByDefault"),
              .enableUpcomingFeature("InferIsolatedConformances"),
              .enableUpcomingFeature("MemberImportVisibility"),
              .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
              .enableUpcomingFeature("NonescapableTypes")
            ],
        ),
        .target(
            name: "InternalAgentPlatformDataModels",
            dependencies: [
              "InternalSharedDataModels"
            ],
            swiftSettings: [
              .swiftLanguageMode(.v6),
              .enableUpcomingFeature("InternalImportsByDefault"),
              .enableUpcomingFeature("InferIsolatedConformances"),
              .enableUpcomingFeature("MemberImportVisibility"),
              .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
              .enableUpcomingFeature("NonescapableTypes")
            ],
        ),
        .target(
            name: "InternalGoogleAIDataModels",
            dependencies: [
              "InternalSharedDataModels"
            ],
            swiftSettings: [
              .swiftLanguageMode(.v6),
              .enableUpcomingFeature("InternalImportsByDefault"),
              .enableUpcomingFeature("InferIsolatedConformances"),
              .enableUpcomingFeature("MemberImportVisibility"),
              .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
              .enableUpcomingFeature("NonescapableTypes")
            ],
        ),
    ]
)
