// swift-tools-version: 6.2

// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

#if compiler(<6.2.3)
  #error("Firebase requires Swift 6.2.3 or higher. Please upgrade to Xcode 26.2 or later.")
#endif  // compiler(<6.2.3)

let defaultSwiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

/// Builds against `FoundationModelsFake` instead of Apple's `FoundationModels` framework.
///
/// The fake is for development and testing only. When the trait is enabled, SwiftPM also defines a
/// `FoundationModelsFake` compilation condition, which the Gemini sources check.
let foundationModelsFakeTrait = Trait(
  name: "FoundationModelsFake",
  description:
    "Builds against FoundationModelsFake instead of Apple's FoundationModels framework, for "
    + "development and testing where the real framework isn't available."
)

#if !canImport(Darwin)
  /// Apple's `FoundationModels` framework only exists on Apple platforms, so the fake is on by
  /// default elsewhere (for example, Linux).
  ///
  /// This checks the machine that runs SwiftPM, so cross-compiling for Linux from macOS still needs
  /// `--traits FoundationModelsFake`.
  let defaultTraits: Set<String> = [foundationModelsFakeTrait.name]
#else
  let defaultTraits: Set<String> = []
#endif  // !canImport(Darwin)

/// The `FoundationModelsFake` dependency, present only when the trait is enabled.
let foundationModelsFakeDependency: Target.Dependency = .product(
  name: "FoundationModelsFake",
  package: "FoundationModelsFake",
  condition: .when(traits: [foundationModelsFakeTrait.name])
)

let package = Package(
  name: "gemini-for-foundation-models",
  platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v11), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(
      name: "GeminiLanguageModel",
      targets: ["GeminiLanguageModel"]
    )
  ],
  traits: [
    foundationModelsFakeTrait,
    .default(enabledTraits: defaultTraits),
  ],
  dependencies: [
    .package(path: "FoundationModelsFake")
  ],
  targets: [
    .target(
      name: "GeminiLanguageModel",
      dependencies: [
        "GeminiAPIClient",
        "GeminiAPIDataModels",
        foundationModelsFakeDependency,
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .target(
      name: "GeminiTestUtilities",
      dependencies: [
        "GeminiAPIClient"
      ],
      path: "Tests/GeminiTestUtilities",
      exclude: [
        "README.md"
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .testTarget(
      name: "GeminiLanguageModelTests",
      dependencies: [
        "GeminiLanguageModel",
        "GeminiTestUtilities",
        foundationModelsFakeDependency,
      ],
      exclude: [
        "IntegrationTests/README.md",
        "README.md",
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .target(
      name: "GeminiAPIClient",
      dependencies: [
        "GeminiAPIDataModels"
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .testTarget(
      name: "GeminiAPIClientTests",
      dependencies: [
        "GeminiAPIClient",
        "GeminiTestUtilities",
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .target(
      name: "GeminiAPIDataModels",
      swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("MemberImportVisibility"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
