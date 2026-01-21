// swift-tools-version: 6.1.2
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

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "FirebaseAILogicExtended",
  platforms: [.iOS(.v15), .macOS(.v12), .macCatalyst(.v15), .tvOS(.v15), .watchOS(.v8)],
  products: [
    .library(
      name: "FirebaseAILogicMacro",
      targets: [
        "FirebaseAILogicMacro",
        // Dependencies for testing
        "FirebaseDependencies",
      ]
    ),
    .executable(
      name: "FirebaseAILogicMacrosClient",
      targets: ["FirebaseAILogicMacrosClient"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0-latest"),
    .package(
      url: "https://github.com/firebase/firebase-ios-sdk.git",
      branch: "ai-structured-output"
    ),
  ],
  targets: [
    .macro(
      name: "FirebaseAILogicMacros",
      dependencies: [
        .product(name: "FirebaseAILogic", package: "firebase-ios-sdk"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    .target(name: "FirebaseAILogicMacro", dependencies: [
      "FirebaseAILogicMacros",
      .product(name: "FirebaseAILogic", package: "firebase-ios-sdk"),
    ]),

    // Dependencies for testing
    .target(name: "FirebaseDependencies", dependencies: [
      .product(name: "FirebaseAILogic", package: "firebase-ios-sdk"),
      .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
      .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
      .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
      .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
    ]),

    // A client of the library, which is able to use the macro in its own code.
    .executableTarget(name: "FirebaseAILogicMacrosClient", dependencies: ["FirebaseAILogicMacro"]),

    // A test target used to develop the macro implementation.
    .testTarget(
      name: "FirebaseGenerableMacroTests",
      dependencies: [
        "FirebaseAILogicMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)
