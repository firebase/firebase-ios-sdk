// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2020 Google LLC
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

// This Package.swift is a Work in Progress, primarily for CI at this point.
// Those interested in experimenting with Swift Package Manager should use the
// spm-master2020 branch for now.

import PackageDescription

let package = Package(
  name: "Firebase",
  platforms: [.iOS(.v9), .macOS(.v10_11), .tvOS(.v10)],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to
    // other packages.
    .library(
      name: "Firebase",
      targets: ["Firebase"]
    ),
    .library(
      name: "FirebaseCore",
      targets: ["FirebaseCore"]
    ),
    .library(
      name: "FirebaseAuth",
      targets: ["FirebaseAuth"]
    ),
    // .library(
    //   name: "FirebaseCrashlytics",
    //   targets: ["FirebaseCrashlytics"]
    // ),
    .library(
      name: "FirebaseFunctions",
      targets: ["FirebaseFunctions"]
    ),
    .library(
      name: "FirebaseInstallations",
      targets: ["FirebaseInstallations"]
    ),
    // .library(
    //   name: "FirebaseInstanceID",
    //   targets: ["FirebaseInstanceID"]
    // ),
    .library(
      name: "FirebaseStorage",
      targets: ["FirebaseStorage"]
    ),
    .library(
      name: "FirebaseStorageSwift",
      targets: ["FirebaseStorageSwift"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/google/promises.git", "1.2.8" ..< "1.3.0"),
    .package(url: "https://github.com/google/gtm-session-fetcher.git", "1.4.0" ..< "2.0.0"),
    .package(url: "https://github.com/paulb777/nanopb.git", .branch("swift-package-manager")),
    // Branches need a force update with a run with the revision set like below.
    //   .package(url: "https://github.com/paulb777/nanopb.git", .revision("564392bd87bd093c308a3aaed3997466efb95f74"))
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .testTarget(
      name: "firebase-test",
      dependencies: [
        "FirebaseAuth",
        "FirebaseFunctions",
        "Firebase",
        "FirebaseCore",
        "FirebaseInstallations",
        // "FirebaseInstanceID",
        "FirebaseStorage",
        "FirebaseStorageSwift",
        "GoogleDataTransport",
        "GoogleUtilities_AppDelegateSwizzler",
        "GoogleUtilities_Environment",
        // "GoogleUtilities_ISASwizzler", // Build needs to disable ARC.
        "GoogleUtilities_Logger",
        "GoogleUtilities_MethodSwizzler",
        "GoogleUtilities_Network",
        "GoogleUtilities_NSData",
        "GoogleUtilities_Reachability",
        "GoogleUtilities_UserDefaults",
        "nanopb",
      ]
    ),
    .target(
      name: "GoogleUtilities_AppDelegateSwizzler",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger",
                     "GoogleUtilities_Network"],
      path: "GoogleUtilities",
      sources: [
        "AppDelegateSwizzler/",
        "SceneDelegateSwizzler/",
        "Common/*.h",
      ],
      publicHeadersPath: "AppDelegateSwizzler/Public",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Environment",
      dependencies: ["FBLPromises"],
      path: "GoogleUtilities/Environment",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    // Tests need OCMock and resource support.

    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    // TODO: ISA_Swizzler requires building without ARC.

    .target(
      name: "GoogleUtilities_MethodSwizzler",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/MethodSwizzler",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Network",
      dependencies: ["GoogleUtilities_Logger", "GoogleUtilities_NSData",
                     "GoogleUtilities_Reachability"],
      path: "GoogleUtilities/Network",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .target(
      name: "GoogleUtilities_NSData",
      path: "GoogleUtilities/NSData+zlib",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ],
      linkerSettings: [
        .linkedLibrary("z"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Reachability",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/Reachability",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_UserDefaults",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/UserDefaults",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "Firebase",
      path: "CoreOnly/Sources",
      publicHeadersPath: "./"
    ),
    .target(
      name: "FirebaseCore",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger"],
      path: "FirebaseCore/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
        .define("FIRCore_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("Firebase_VERSION", to: "0.0.1"), // TODO: Fix version
        // TODO: - Add support for cflags cSetting so that we can set the -fno-autolink option
      ]
    ),
    .target(
      name: "FirebaseAuth",
      dependencies: ["FirebaseCore",
                     "GoogleUtilities_Environment",
                     "GoogleUtilities_AppDelegateSwizzler",
                     "GTMSessionFetcherCore"],
      path: "FirebaseAuth/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRAuth_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("FIRAuth_MINOR_VERSION", to: "1.1"), // TODO: Fix version
      ]
    ),
    .target(
      name: "FirebaseFunctions",
      dependencies: ["FirebaseCore", "GTMSessionFetcherCore"],
      path: "Functions/FirebaseFunctions",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRFunctions_VERSION", to: "0.0.1"), // TODO: Fix version
      ]
    ),
    // .target(
    //   name: "FirebaseInstanceID",
    //   dependencies: ["FirebaseCore", "FirebaseInstallations",
    //                  "GoogleUtilities_Environment", "GoogleUtilities_UserDefaults"],
    //   path: "Firebase/InstanceID",
    //   publicHeadersPath: "Public",
    //   cSettings: [
    //     .headerSearchPath("../../"),
    //     .define("FIRInstanceID_LIB_VERSION", to: "0.0.1"), // TODO: Fix version
    //   ]
    // ),
    .target(
      name: "FirebaseInstallations",
      dependencies: ["FirebaseCore", "FBLPromises",
                     "GoogleUtilities_Environment", "GoogleUtilities_UserDefaults"],
      path: "FirebaseInstallations/Source/Library",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../../"),
      ]
    ),
    .target(
      name: "FirebaseStorage",
      dependencies: ["FirebaseCore", "GTMSessionFetcherCore"],
      path: "FirebaseStorage/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRStorage_VERSION", to: "0.0.1"), // TODO: Fix version
      ]
    ),
    .target(
      name: "FirebaseStorageSwift",
      dependencies: ["FirebaseStorage"],
      path: "FirebaseStorageSwift/Sources"
    ),
    .target(
      name: "GoogleDataTransport",
      dependencies: ["nanopb"],
      path: ".",
      sources: [
        "GoogleDataTransport/GDTCORLibrary",
        "GoogleDataTransportCCTSupport/GDTCCTLibrary",
      ],
      publicHeadersPath: "GoogleDataTransport/GDTCORLibrary/Public",
      cSettings: [
        .headerSearchPath("."),
        .define("GDTCOR_VERSION", to: "0.0.1"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
  ],
  cLanguageStandard: .c99
)
