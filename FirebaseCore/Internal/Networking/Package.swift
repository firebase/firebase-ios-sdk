// swift-tools-version:6.2

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

// A standalone package for developing and testing the networking code on its own, including on
// Linux: `swift test` in this directory.
//
// It isn't published. Firebase's root Package.swift builds the same sources as the
// `FirebaseNetworkingInternal` target. This package exists because SwiftPM links every test target
// of a package into one test executable on Linux, and most of Firebase's test targets don't build
// there.
//
// `WireCompatibility` is a symlink to FirebaseTestingSupport/WireCompatibility/Sources, because a
// target's sources must be inside its package.
let package = Package(
  name: "FirebaseNetworkingInternal",
  platforms: [.iOS(.v15), .macCatalyst(.v15), .macOS(.v11), .tvOS(.v15), .watchOS(.v8)],
  targets: [
    .target(
      name: "FirebaseNetworkingInternal",
      path: "Sources"
    ),
    .target(
      name: "FirebaseWireCompatibilityTestingSupport",
      path: "WireCompatibility"
    ),
    .testTarget(
      name: "FirebaseNetworkingInternalTests",
      dependencies: [
        "FirebaseNetworkingInternal",
        "FirebaseWireCompatibilityTestingSupport",
      ],
      path: "Tests"
    ),
  ]
)
