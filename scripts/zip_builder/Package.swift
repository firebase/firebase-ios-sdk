// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import PackageDescription

let package = Package(
  name: "ZipBuilder",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "zip-builder", targets: ["ZipBuilder"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    .package(url: "https://github.com/swiftlang/swift-package-manager.git", branch: "main"),
    .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.24.0"),
    // XcodeProj 8 declares no platforms (macOS 10.13 by default), but AEXML 4.7.2+ requires macOS
    // 10.14, which SwiftPM rejects. XcodeProj 9.10.1+ declares macOS 11 but types its
    // BuildSettings.
    .package(url: "https://github.com/tadija/AEXML.git", "4.7.0" ..< "4.7.2"),
  ],
  targets: [
    // The zip builder (see docs/how-it-works.md).
    .executableTarget(
      name: "ZipBuilder",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "SwiftPMDataModel-auto", package: "swift-package-manager"),
        .product(name: "XcodeProj", package: "XcodeProj"),
        // Only here to pin its version (see above).
        .product(name: "AEXML", package: "AEXML"),
      ]
    ),
    .testTarget(
      name: "ZipBuilderTests",
      dependencies: ["ZipBuilder"]
    ),
  ]
)
