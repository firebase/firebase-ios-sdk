// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
  name: "FirebaseCrashlyticsTelemetry",
  platforms: [
    .macOS(.v12),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v7),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "FirebaseCrashlyticsTelemetry",
      targets: ["FirebaseCrashlyticsTelemetry"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift-core.git",
      .upToNextMajor(from: "2.3.0")
    ),
    .package(url: "https://github.com/firebase/firebase-telemetry-persistence.git", branch: "main"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
    .package(url: "https://github.com/firebase/nanopb.git", "2.30910.0" ..< "2.30911.0"),
  ],
  targets: [
    .target(
      name: "FirebaseCrashlyticsTelemetry",
      dependencies: [
        "OpentelemetryProtos",
        "PersistenceWrapper",
        "URLSessionInstrumentation",
        .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        .product(name: "StdoutExporter", package: "opentelemetry-swift-core"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "Sources",
      exclude: [
        "third_party/README.md",
        "third_party/opentelemetry-proto",
        "third_party/opentelemetry-swift",
      ],
      cSettings: [
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
    .target(
      name: "PersistenceWrapper",
      dependencies: [
        .product(name: "FirebaseTelemetryPersistence", package: "firebase-telemetry-persistence"),
      ],
      path: "SourcesObjC"
    ),
    .target(
      name: "NetworkStatus",
      dependencies: [
        .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
      ],
      path: "Sources/third_party/opentelemetry-swift/Sources/Instrumentation/NetworkStatus",
      linkerSettings: [.linkedFramework("CoreTelephony", .when(platforms: [.iOS]))]
    ),
    .target(
      name: "URLSessionInstrumentation",
      dependencies: [
        .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core"),
        "NetworkStatus",
      ],
      path: "Sources/third_party/opentelemetry-swift/Sources/Instrumentation/URLSession",
      exclude: ["README.md"]
    ),
    .target(
      name: "OpentelemetryProtos",
      dependencies: [
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "Sources/third_party/opentelemetry-proto/Protogen/nanopb",
      publicHeadersPath: ".",
      cSettings: [
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
    .testTarget(
      name: "CrashlyticsTelemetryUnitTests",
      dependencies: [
        "FirebaseCrashlyticsTelemetry",
      ],
      path: "Tests/Unit",
      cSettings: [
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
