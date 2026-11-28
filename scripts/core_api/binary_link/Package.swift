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

// Runs the FirebaseAnalytics link test (FirebaseCore/Tests/AnalyticsLink) with FirebaseCore linked
// as a dynamic library, as it is in apps that use dynamic frameworks. The prebuilt
// FirebaseAnalytics binary is a static framework, so it's linked into the test and must get
// FirebaseCore's symbols from the dynamic library.
//
// The root package can't declare a dynamic FirebaseCore product without shipping it to users, so
// the dynamic library is declared in the CoreDynamic package next to this one. Because the test
// depends on it, Swift Build builds FirebaseCore and its dependencies as dynamic libraries and
// links the test against them instead of a static copy.
//
// Test-only. See FirebaseCore/Tests/APIBaselines/README.md.

import PackageDescription

let package = Package(
  name: "CoreBinaryLink",
  platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15)],
  dependencies: [
    .package(name: "Firebase", path: "../../.."),
    .package(name: "CoreDynamic", path: "CoreDynamic"),
  ],
  targets: [
    .testTarget(
      name: "CoreAnalyticsLinkDynamic",
      dependencies: [
        .product(name: "FirebaseCoreDynamic", package: "CoreDynamic"),
        .product(name: "FirebaseAnalytics", package: "Firebase"),
      ],
      cSettings: [
        // The test imports FirebaseCore's internal headers by repo-relative path. A header search
        // path outside the package needs an unsafe flag, which is allowed because this package is
        // never a dependency.
        .unsafeFlags(["-I", Context.packageDirectory + "/../../.."]),
      ]
    ),
  ]
)
