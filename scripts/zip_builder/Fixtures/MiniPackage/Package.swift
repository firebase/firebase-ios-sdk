// swift-tools-version:6.0
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

// A small package exercising the zip builder's mapping rules (see docs/how-it-works.md).

import PackageDescription

let package = Package(
  name: "Mini",
  platforms: [.iOS(.v15), .macOS(.v11), .tvOS(.v15)],
  products: [
    .library(name: "Mini", targets: ["SwiftLib"]),
    .library(name: "MiniCore", targets: ["CoreC"]),
    .library(name: "MiniHeaders", type: .dynamic, targets: ["HeaderOnly"]),
    .library(name: "MiniPrebuilt", targets: ["Wrapper"]),
  ],
  targets: [
    // C-family target with an umbrella header, a private header, settings, and a resource.
    .target(
      name: "CoreC",
      path: "Sources/CoreC",
      resources: [.process("PrivacyInfo.xcprivacy")],
      publicHeadersPath: "include",
      cSettings: [
        .define("CORE_FLAG", to: "1"),
        .define("CORE_IOS_ONLY", .when(platforms: [.iOS])),
        .headerSearchPath("."),
      ],
      linkerSettings: [.linkedFramework("Security")]
    ),
    // Companion target, merged into SwiftLib when configured.
    .target(
      name: "CoreCInternal",
      dependencies: ["CoreC"],
      path: "Sources/CoreCInternal",
      publicHeadersPath: "Public"
    ),
    // Swift target with a hyphen-free name, a language mode, and a copied resource folder.
    .target(
      name: "SwiftLib",
      dependencies: ["CoreCInternal", "Mini-Extras"],
      path: "Sources/SwiftLib",
      resources: [.copy("Resources")],
      swiftSettings: [
        .define("SWIFT_FLAG"),
        .define("SWIFT_MACOS_ONLY", .when(platforms: [.macOS])),
        .swiftLanguageMode(.v5),
      ]
    ),
    // A module name with a hyphen (C99 name `Mini_Extras`), without an umbrella header.
    .target(
      name: "Mini-Extras",
      path: "Sources/MiniExtras",
      publicHeadersPath: "include"
    ),
    // Header-only target: its source is a code-free stub, but its public header has declarations.
    .target(
      name: "HeaderOnly",
      path: "Sources/HeaderOnly",
      publicHeadersPath: "include"
    ),
    // Wrapper target: only code-free stubs; exists to attach the binary target. A privacy
    // manifest alone doesn't make it a framework.
    .target(
      name: "Wrapper",
      dependencies: [.target(name: "Prebuilt", condition: .when(platforms: [.iOS]))],
      path: "Sources/Wrapper",
      resources: [.process("PrivacyInfo.xcprivacy")]
    ),
    .binaryTarget(name: "Prebuilt", path: "Prebuilt.xcframework"),
    .testTarget(name: "SwiftLibTests", dependencies: ["SwiftLib"], path: "Tests/SwiftLibTests"),

    // Targets no product uses; tests reach them through `products.add` or directly.
    // Code-free, but ships real resources, so it's a framework.
    .target(
      name: "ResourceOnly",
      path: "Sources/ResourceOnly",
      resources: [.process("Resources")]
    ),
    // Has a custom module map (include/module.modulemap) listing a header its umbrella doesn't.
    .target(
      name: "CustomMap",
      path: "Sources/CustomMap",
      publicHeadersPath: "include"
    ),
    // Depends on a system library, which isn't supported.
    .target(
      name: "SystemUser",
      dependencies: ["CSystem"],
      path: "Sources/SystemUser"
    ),
    .systemLibrary(name: "CSystem", path: "Sources/CSystem"),
    // C++ sources including by paths only the include directories serve, not the frameworks:
    // CppBase's by a nested path (`<cpp_base/value.h>`), Mini-Extras' at its top (`"MEOne.h"`).
    .target(name: "CppBase", path: "Sources/CppBase", publicHeadersPath: "include"),
    .target(
      name: "CppUser",
      dependencies: ["CppBase", "Mini-Extras"],
      path: "Sources/CppUser",
      publicHeadersPath: "include",
      // Catalyst compiles the iOS code, so a dynamic CppUser links UIKit there too.
      linkerSettings: [.linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS]))]
    ),
  ]
)
