// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

/*
 * Copyright 2019 Google
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
  name: "ReleaseTooling",
  products: [
    .executable(name: "firebase-releaser", targets: ["FirebaseReleaser"]),
    .executable(name: "zip-builder", targets: ["ZipBuilder"]),
    .executable(name: "podspecs-tester", targets: ["PodspecsTester"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", .exact("0.1.0")),
  ],
  targets: [
    .target(
      name: "ZipBuilder",
      dependencies: ["ArgumentParser", "FirebaseManifest", "Utils"]
    ),
    .target(
      name: "FirebaseManifest"
    ),
    .target(
      name: "FirebaseReleaser",
      dependencies: ["ArgumentParser", "FirebaseManifest", "Utils"]
    ),
    .target(
      name: "PodspecsTester",
      dependencies: ["ArgumentParser", "FirebaseManifest", "Utils"]
    ),
    .target(
      name: "Utils"
    ),
  ]
)
