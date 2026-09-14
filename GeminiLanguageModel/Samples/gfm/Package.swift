// swift-tools-version: 6.1

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

let defaultSwiftSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
  .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
  name: "gfm",
  platforms: [.macOS(.v15), .iOS(.v18)],
  products: [
    .executable(
      name: "gfm",
      targets: ["GFM"]
    ),
    .library(
      name: "GFMCore",
      targets: ["GFMCore"]
    ),
  ],
  dependencies: [
    .package(path: "../../", traits: ["GeminiDeveloperAPIEnvironmentAuth"]),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
  ],
  targets: [
    .executableTarget(
      name: "GFM",
      dependencies: [
        "GFMCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .target(
      name: "GFMCore",
      dependencies: [
        .product(name: "GeminiLanguageModel", package: "GeminiLanguageModel"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: defaultSwiftSettings
    ),
    .testTarget(
      name: "GFMTests",
      dependencies: [
        "GFMCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: defaultSwiftSettings
    ),
  ],
  swiftLanguageModes: [.v6]
)
