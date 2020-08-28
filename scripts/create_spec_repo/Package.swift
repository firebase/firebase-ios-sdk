// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
 * Copyright 2020 Google LLC
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
  name: "PodSpecBuilder",
  products: [
    .executable(name: "spec-repo-builder", targets: ["SpecRepoBuilder"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.0")),
  ],
  targets: [
    .target(
      name: "SpecRepoBuilder",
      dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")]
    ),
  ]
)
