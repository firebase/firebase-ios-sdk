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

let package = Package(
  name: "gemini-for-foundation-models",
  platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v10_15), .tvOS(.v15), .watchOS(.v7)],
  products: [
    .library(
      name: "GeminiForFoundationModels",
      targets: ["GeminiForFoundationModels"]
    )
  ],
  targets: [
    .target(
      name: "GeminiForFoundationModels"
    ),
    .testTarget(
      name: "GeminiForFoundationModelsTests",
      dependencies: [
        "GeminiForFoundationModels"
      ]
    ),
    .target(
      name: "SharedDataModels"
    ),
    .target(
      name: "GenerateContentDataModels",
      dependencies: [
        "SharedDataModels"
      ]
    ),
    .target(
      name: "HTTPStreamingClient"
    ),
    .testTarget(
      name: "HTTPStreamingClientTests",
      dependencies: [
        "HTTPStreamingClient"
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
