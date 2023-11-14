// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
 * Copyright 2021 Google LLC
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
  name: "CodeCoverage",
  products: [
    // Products define the executables and libraries a package produces, and make them visible to
    // other packages.
    .executable(
      name: "CoverageReportGenerator",
      targets: ["CoverageReportGenerator"]
    ),
    .executable(
      name: "UpdatedFilesCollector",
      targets: ["UpdatedFilesCollector"]
    ),
    .executable(
      name: "IncrementalCoverageReportGenerator",
      targets: ["IncrementalCoverageReportGenerator"]
    ),
    .executable(
      name: "BinarySizeReportGenerator",
      targets: ["BinarySizeReportGenerator"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "0.2.0"),
  ],
  targets: [
    .target(
      name: "CoverageReportGenerator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Utils",
      ]
    ),
    .target(
      name: "UpdatedFilesCollector",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(
      name: "IncrementalCoverageReportGenerator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Utils",
      ]
    ),
    .target(
      name: "BinarySizeReportGenerator",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Utils",
      ]
    ),
    .target(
      name: "Utils"
    ),
  ]
)
