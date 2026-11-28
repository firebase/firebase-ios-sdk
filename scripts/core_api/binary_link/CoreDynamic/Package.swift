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

// A dynamic library product of FirebaseCore, for the dynamic link test in the parent directory.
// It must be in its own package: a target can't depend on a product of its own package.
//
// Test-only. Don't add a dynamic product to the root package, because users would get it.

import PackageDescription

let package = Package(
  name: "CoreDynamic",
  platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15)],
  products: [
    .library(name: "FirebaseCoreDynamic", type: .dynamic, targets: ["FirebaseCoreDynamic"]),
  ],
  dependencies: [
    .package(name: "Firebase", path: "../../../.."),
  ],
  targets: [
    .target(
      name: "FirebaseCoreDynamic",
      dependencies: [.product(name: "FirebaseCore", package: "Firebase")]
    ),
  ]
)
