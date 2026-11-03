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

import CompilerPluginSupport
import PackageDescription

#if compiler(<6.2.3)
  #error("Firebase requires Swift 6.2.3 or higher. Please upgrade to Xcode 26.2 or later.")
#endif  // compiler(<6.2.3)

/// Swift settings shared by every target in the fake.
let swiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .strictMemorySafety(),
]

/// Swift settings for the fake's library and its tests.
///
/// Public declarations carry the same `@available` attributes as Apple's `FoundationModels`, so
/// code that uses the fake is checked exactly like code that uses the real framework. The fake
/// itself deploys back to Firebase's minimum OS versions, where Swift rejects some of those
/// attributes (for example, a newer enum case with an associated value). Apple builds its framework
/// with a newer deployment target, so it doesn't hit this. Disabling availability checking inside
/// the fake keeps the attributes identical to Apple's.
///
/// With checking disabled, Swift no longer rules out `@available(*, unavailable)` overloads, so
/// the fake marks those `@_disfavoredOverload` to keep them from being chosen.
let availabilityExemptSwiftSettings: [SwiftSetting] =
  swiftSettings + [.unsafeFlags(["-Xfrontend", "-disable-availability-checking"])]

let package = Package(
  name: "FoundationModelsFake",
  platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v11), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(name: "FoundationModelsFake", targets: ["FoundationModelsFake"])
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"605.0.0"),
    .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
  ],
  targets: [
    .macro(
      name: "FoundationModelsFakeMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "FoundationModelsFake",
      dependencies: [
        "FoundationModelsFakeMacros",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "DequeModule", package: "swift-collections"),
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
      swiftSettings: availabilityExemptSwiftSettings
    ),
    .testTarget(
      name: "FoundationModelsFakeTests",
      dependencies: [
        "FoundationModelsFake",
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
      swiftSettings: availabilityExemptSwiftSettings
    ),
    .testTarget(
      name: "FoundationModelsFakeMacrosTests",
      dependencies: [
        "FoundationModelsFakeMacros",
        .product(name: "SwiftDiagnostics", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      exclude: ["Snapshots"],
      swiftSettings: swiftSettings
    ),
  ],
  swiftLanguageModes: [.v6]
)
