// swift-tools-version: 6.1
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
  name: "GeneratedFirebaseAI",
  platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(
      name: "GeneratedFirebaseAI",
      targets: ["GeneratedFirebaseAI"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.6.0"),
    .package(url: "https://github.com/google/test-server.git", branch: "main"),
  ],
  targets: [
    .target(
      name: "GeneratedFirebaseAI",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
        // TODO(daymxn): Before release, investigate releasing the Interop layers for AppCheck/Auth.
        .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
        .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
      ]
    ),
    .testTarget(
      name: "GeneratedFirebaseAITests",
      dependencies: [
        "GeneratedFirebaseAI",
        .product(name: "TestServer", package: "TestServer")
      ],
      path: "Tests",
      exclude: [
        "test-server.yml",
        "Recordings"
      ]
    ),
  ]
)
