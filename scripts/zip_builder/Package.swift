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
  // Direct dependencies are pinned to exact commits (the comment names the version), so a build
  // can't pick up an unreviewed change. Bump one by changing its revision and running
  // `swift package resolve`; Package.resolved pins the transitive ones.
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      revision: "6a52f3251125d74daf04fcbd5e6f08a75d074382" // 1.8.2
    ),
    .package(
      url: "https://github.com/apple/swift-log.git",
      revision: "4038b6a4f74a1426f47eb1dd5b4bb5628a15d597" // 1.16.1
    ),
    .package(
      url: "https://github.com/swiftlang/swift-package-manager.git",
      revision: "7137197d30da49413553f3dd5e03988b967be36a" // main
    ),
    .package(
      url: "https://github.com/tuist/XcodeProj.git",
      revision: "a97494b14b5ba3184b48c050d034c7534356e0ae" // 9.17.8
    ),
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
      ]
    ),
    .testTarget(
      name: "ZipBuilderTests",
      dependencies: ["ZipBuilder"]
    ),
  ]
)
