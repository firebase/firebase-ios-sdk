// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 * Copyright 2025 Google
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

/// Package containing CLI executables for our larger scripts that are a bit harder to follow in bash form, or
/// that need more advanced flag/optional requirements.
let package = Package(
  name: "RepoScripts",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "tests", targets: ["Tests"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.6.2"),
    .package(url: "https://github.com/apple/swift-log", exact: "1.6.2"),
  ],
  targets: [
    .executableTarget(
      name: "Tests",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
        .byName(name: "Util"),
      ]
    ),
    .target(
      name: "Util",
      dependencies: [
        .product(name: "Logging", package: "swift-log")
      ]
    ),
  ]
)
