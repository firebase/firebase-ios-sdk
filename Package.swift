// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

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

import PackageDescription
import class Foundation.ProcessInfo

let firebaseVersion = "9.6.0"

let package = Package(
  name: "Firebase",
  platforms: [.iOS(.v11), .macOS(.v10_12), .tvOS(.v12), .watchOS(.v7)],
  products: [
    .library(
      name: "FirebaseAnalytics",
      targets: ["FirebaseAnalyticsTarget"]
    ),
    .library(
      name: "FirebaseAnalyticsWithoutAdIdSupport",
      targets: ["FirebaseAnalyticsWithoutAdIdSupportTarget"]
    ),
    .library(
      name: "FirebaseAnalyticsOnDeviceConversion",
      targets: ["FirebaseAnalyticsOnDeviceConversionTarget"]
    ),
    .library(
      name: "FirebaseAnalyticsSwift",
      targets: ["FirebaseAnalyticsSwiftTarget"]
    ),
    .library(
      name: "FirebaseAuth",
      targets: ["FirebaseAuth"]
    ),
    .library(
      name: "FirebaseAppCheck",
      targets: ["FirebaseAppCheck"]
    ),
    .library(
      name: "FirebaseAppDistribution-Beta",
      targets: ["FirebaseAppDistributionTarget"]
    ),
    .library(
      name: "FirebaseAuthCombine-Community",
      targets: ["FirebaseAuthCombineSwift"]
    ),
    .library(
      name: "FirebaseFirestoreCombine-Community",
      targets: ["FirebaseFirestoreCombineSwift"]
    ),
    .library(
      name: "FirebaseFunctionsCombine-Community",
      targets: ["FirebaseFunctionsCombineSwift"]
    ),
    .library(
      name: "FirebaseStorageCombine-Community",
      targets: ["FirebaseStorageCombineSwift"]
    ),
    .library(
      name: "FirebaseCrashlytics",
      targets: ["FirebaseCrashlytics"]
    ),
    .library(
      name: "FirebaseDatabase",
      targets: ["FirebaseDatabase"]
    ),
    .library(
      name: "FirebaseDatabaseSwift",
      targets: ["FirebaseDatabaseSwift"]
    ),
    .library(
      name: "FirebaseDynamicLinks",
      targets: ["FirebaseDynamicLinksTarget"]
    ),
    .library(
      name: "FirebaseFirestore",
      targets: ["FirebaseFirestoreTarget"]
    ),
    .library(
      name: "FirebaseFirestoreSwift",
      targets: ["FirebaseFirestoreSwiftTarget"]
    ),
    .library(
      name: "FirebaseFunctions",
      targets: ["FirebaseFunctions"]
    ),
    .library(
      name: "FirebaseInAppMessaging-Beta",
      targets: ["FirebaseInAppMessagingTarget"]
    ),
    .library(
      name: "FirebaseInAppMessagingSwift-Beta",
      targets: ["FirebaseInAppMessagingSwift"]
    ),
    .library(
      name: "FirebaseInstallations",
      targets: ["FirebaseInstallations"]
    ),
    .library(
      name: "FirebaseMessaging",
      targets: ["FirebaseMessaging"]
    ),
    .library(
      name: "FirebaseMLModelDownloader",
      targets: ["FirebaseMLModelDownloader"]
    ),
    .library(
      name: "FirebasePerformance",
      targets: ["FirebasePerformanceTarget"]
    ),
    .library(
      name: "FirebaseRemoteConfig",
      targets: ["FirebaseRemoteConfig"]
    ),
    .library(
      name: "FirebaseRemoteConfigSwift",
      targets: ["FirebaseRemoteConfigSwift"]
    ),
    .library(
      name: "FirebaseStorage",
      targets: ["FirebaseStorage"]
    ),
  ],
  dependencies: [
    .package(
      name: "Promises",
      url: "https://github.com/google/promises.git",
      "2.1.0" ..< "3.0.0"
    ),
    .package(
      name: "SwiftProtobuf",
      url: "https://github.com/apple/swift-protobuf.git",
      "1.19.0" ..< "2.0.0"
    ),
    .package(
      name: "GoogleAppMeasurement",
      url: "https://github.com/google/GoogleAppMeasurement.git",
      // Note that CI changes the version to the head of main for CI.
      // See scripts/setup_spm_tests.sh.
      .exact("9.6.0")
    ),
    .package(
      name: "GoogleDataTransport",
      url: "https://github.com/google/GoogleDataTransport.git",
      "9.1.4" ..< "10.0.0"
    ),
    .package(
      name: "GoogleUtilities",
      url: "https://github.com/google/GoogleUtilities.git",
      "7.7.1" ..< "8.0.0"
    ),
    .package(
      name: "GTMSessionFetcher",
      url: "https://github.com/google/gtm-session-fetcher.git",
      "1.7.2" ..< "3.0.0"
    ),
    .package(
      name: "nanopb",
      url: "https://github.com/firebase/nanopb.git",
      "2.30909.0" ..< "2.30910.0"
    ),
    .package(
      name: "abseil",
      url: "https://github.com/firebase/abseil-cpp-SwiftPM.git",
      "0.20220203.1" ..< "0.20220204.0"
    ),
    .package(
      name: "gRPC",
      url: "https://github.com/grpc/grpc-ios.git",
      "1.44.0-grpc" ..< "1.45.0-grpc"
    ),
    .package(
      name: "OCMock",
      url: "https://github.com/erikdoe/ocmock.git",
      .revision("c5eeaa6dde7c308a5ce48ae4d4530462dd3a1110")
    ),
    .package(
      name: "leveldb",
      url: "https://github.com/firebase/leveldb.git",
      "1.22.2" ..< "1.23.0"
    ),
    .package(
      name: "GCDWebServer",
      url: "https://github.com/SlaunchaMan/GCDWebServer.git",
      .revision("935e2736044e71e5341663c3cc9a335ba6867a2b")
    ),
  ],
  targets: [
    .target(
      name: "Firebase",
      path: "CoreOnly/Sources",
      publicHeadersPath: "./"
    ),
    .target(
      name: "FirebaseCore",
      dependencies: [
        "Firebase",
        "FirebaseCoreDiagnostics",
        "FirebaseCoreInternal",
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULLogger", package: "GoogleUtilities"),
      ],
      path: "FirebaseCore/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
        .define("Firebase_VERSION", to: firebaseVersion),
        // TODO: - Add support for cflags cSetting so that we can set the -fno-autolink option
      ],
      linkerSettings: [
        .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
        .linkedFramework("AppKit", .when(platforms: [.macOS])),
      ]
    ),
    .testTarget(
      name: "CoreUnit",
      dependencies: [
        "FirebaseCore",
        "SharedTestUtilities",
        "HeartbeatLoggingTestUtils",
        "OCMock",
      ],
      path: "FirebaseCore/Tests/Unit",
      exclude: ["Resources/GoogleService-Info.plist"],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

    // MARK: - Firebase Core Extension

    // Extension of FirebaseCore for consuming by Swift product SDKs.
    .target(
      name: "FirebaseCoreExtension",
      path: "FirebaseCore/Extension",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    // MARK: - Firebase Core Internal

    // Shared collection of APIs for internal FirebaseCore usage.
    .target(
      name: "FirebaseCoreInternal",
      dependencies: [
        .product(name: "GULNSData", package: "GoogleUtilities"),
      ],
      path: "FirebaseCore/Internal/Sources"
    ),
    .target(
      name: "HeartbeatLoggingTestUtils",
      dependencies: ["FirebaseCoreInternal"],
      path: "HeartbeatLoggingTestUtils/Sources"
    ),
    .testTarget(
      name: "FirebaseCoreInternalTests",
      dependencies: [
        "FirebaseCoreInternal",
        "HeartbeatLoggingTestUtils",
      ],
      path: "FirebaseCore/Internal/Tests"
    ),

    .target(
      name: "FirebaseCoreDiagnostics",
      dependencies: [
        .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULLogger", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "Firebase/CoreDiagnostics/FIRCDLibrary",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../.."),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
    .target(
      name: "FirebaseABTesting",
      dependencies: ["FirebaseCore"],
      path: "FirebaseABTesting/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "ABTestingUnit",
      dependencies: ["FirebaseABTesting", "OCMock"],
      path: "FirebaseABTesting/Tests/Unit",
      resources: [.process("Resources")],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

    .target(
      name: "FirebaseAnalyticsTarget",
      dependencies: [.target(name: "FirebaseAnalyticsWrapper",
                             condition: .when(platforms: [.iOS, .macOS, .tvOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseAnalyticsWrap"
    ),

    .target(
      name: "FirebaseAnalyticsWrapper",
      dependencies: [
        .target(name: "FirebaseAnalytics", condition: .when(platforms: [.iOS, .macOS, .tvOS])),
        .product(name: "GoogleAppMeasurement",
                 package: "GoogleAppMeasurement",
                 condition: .when(platforms: [.iOS, .macOS, .tvOS])),
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULMethodSwizzler", package: "GoogleUtilities"),
        .product(name: "GULNSData", package: "GoogleUtilities"),
        .product(name: "GULNetwork", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "FirebaseAnalyticsWrapper",
      linkerSettings: [
        .linkedLibrary("sqlite3"),
        .linkedLibrary("c++"),
        .linkedLibrary("z"),
        .linkedFramework("StoreKit"),
      ]
    ),
    .binaryTarget(
      name: "FirebaseAnalytics",
      url: "https://dl.google.com/firebase/ios/swiftpm/9.6.0/FirebaseAnalytics.zip",
      checksum: "b2f2b38e2764a09af0781c61093693eb61739d0a43f203f2e4cbf10e4aa6c329"
    ),
    .target(
      name: "FirebaseAnalyticsSwiftTarget",
      dependencies: [.target(name: "FirebaseAnalyticsSwift",
                             condition: .when(platforms: [.iOS, .macOS, .tvOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseAnalyticsSwiftWrap"
    ),
    .target(
      name: "FirebaseAnalyticsSwift",
      dependencies: ["FirebaseAnalyticsWrapper"],
      path: "FirebaseAnalyticsSwift/Sources"
    ),

    .target(
      name: "FirebaseAnalyticsWithoutAdIdSupportTarget",
      dependencies: [.target(name: "FirebaseAnalyticsWithoutAdIdSupportWrapper",
                             condition: .when(platforms: [.iOS, .macOS, .tvOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseAnalyticsWithoutAdIdSupportWrap"
    ),
    .target(
      name: "FirebaseAnalyticsWithoutAdIdSupportWrapper",
      dependencies: [
        .target(name: "FirebaseAnalytics", condition: .when(platforms: [.iOS, .macOS, .tvOS])),
        .product(name: "GoogleAppMeasurementWithoutAdIdSupport",
                 package: "GoogleAppMeasurement",
                 condition: .when(platforms: [.iOS])),
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULMethodSwizzler", package: "GoogleUtilities"),
        .product(name: "GULNSData", package: "GoogleUtilities"),
        .product(name: "GULNetwork", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "FirebaseAnalyticsWithoutAdIdSupportWrapper",
      linkerSettings: [
        .linkedLibrary("sqlite3"),
        .linkedLibrary("c++"),
        .linkedLibrary("z"),
        .linkedFramework("StoreKit"),
      ]
    ),

    .target(
      name: "FirebaseAnalyticsOnDeviceConversionTarget",
      dependencies: [
        .product(name: "GoogleAppMeasurementOnDeviceConversion",
                 package: "GoogleAppMeasurement",
                 condition: .when(platforms: [.iOS])),
      ],
      path: "FirebaseAnalyticsOnDeviceConversionWrapper",
      linkerSettings: [
        .linkedLibrary("c++"),
      ]
    ),

    .target(
      name: "FirebaseAppDistributionTarget",
      dependencies: [.target(name: "FirebaseAppDistribution",
                             condition: .when(platforms: [.iOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseAppDistributionWrap"
    ),
    .target(
      name: "FirebaseAppDistribution",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULUserDefaults", package: "GoogleUtilities"),
      ],
      path: "FirebaseAppDistribution/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "AppDistributionUnit",
      dependencies: ["FirebaseAppDistribution", "OCMock"],
      path: "FirebaseAppDistribution/Tests/Unit",
      exclude: ["Swift/"],
      resources: [.process("Resources")],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .testTarget(
      name: "AppDistributionUnitSwift",
      dependencies: ["FirebaseAppDistribution"],
      path: "FirebaseAppDistribution/Tests/Unit/Swift",
      cSettings: [
        .headerSearchPath("../../../.."),
      ]
    ),

    .target(
      name: "FirebaseAuth",
      dependencies: [
        "FirebaseCore",
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GTMSessionFetcherCore", package: "GTMSessionFetcher"),
      ],
      path: "FirebaseAuth/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ],
      linkerSettings: [
        .linkedFramework("Security"),
        .linkedFramework("SafariServices", .when(platforms: [.iOS])),
      ]
    ),
    // Internal headers only for consuming from Swift.
    .target(
      name: "FirebaseAuthInterop",
      path: "FirebaseAuth/Interop",
      exclude: [
        "CMakeLists.txt",
      ],
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "AuthUnit",
      dependencies: ["FirebaseAuth", "OCMock", "HeartbeatLoggingTestUtils"],
      path: "FirebaseAuth/Tests/Unit",
      exclude: [
        "FIRAuthKeychainServicesTests.m", // TODO: figure out SPM keychain testing
        "FIRAuthTests.m",
        "FIRUserTests.m",
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseAuthCombineSwift",
      dependencies: ["FirebaseAuth"],
      path: "FirebaseCombineSwift/Sources/Auth"
    ),
    .target(
      name: "FirebaseFirestoreCombineSwift",
      dependencies: [
        "FirebaseFirestore",
        "FirebaseFirestoreSwift",
      ],
      path: "FirebaseCombineSwift/Sources/Firestore"
    ),
    .target(
      name: "FirebaseStorageCombineSwift",
      dependencies: [
        "FirebaseStorage",
        "FirebaseStorageInternal",
      ],
      path: "FirebaseCombineSwift/Sources/Storage"
    ),
    .target(
      name: "FirebaseCrashlytics",
      dependencies: ["FirebaseCore", "FirebaseInstallations",
                     .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
                     .product(name: "GULEnvironment", package: "GoogleUtilities"),
                     .product(name: "FBLPromises", package: "Promises"),
                     .product(name: "nanopb", package: "nanopb")],
      path: "Crashlytics",
      exclude: [
        "run",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "ProtoSupport/",
        "UnitTests/",
        "generate_project.sh",
        "upload-symbols",
        "third_party/libunwind/LICENSE",
      ],
      sources: [
        "Crashlytics/",
        "Protogen/",
        "Shared/",
        "third_party/libunwind/dwarf.h",
      ],
      publicHeadersPath: "Crashlytics/Public",
      cSettings: [
        .headerSearchPath(".."),
        .define("DISPLAY_VERSION", to: firebaseVersion),
        .define("CLS_SDK_NAME", to: "Crashlytics iOS SDK", .when(platforms: [.iOS])),
        .define("CLS_SDK_NAME", to: "Crashlytics macOS SDK", .when(platforms: [.macOS])),
        .define("CLS_SDK_NAME", to: "Crashlytics tvOS SDK", .when(platforms: [.tvOS])),
        .define("CLS_SDK_NAME", to: "Crashlytics watchOS SDK", .when(platforms: [.watchOS])),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ],
      linkerSettings: [
        .linkedFramework("Security"),
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
      ]
    ),

    .target(
      name: "FirebaseDatabase",
      dependencies: [
        "FirebaseCore",
        "leveldb",
      ],
      path: "FirebaseDatabase/Sources",
      exclude: [
        "third_party/Wrap-leveldb/LICENSE",
        "third_party/SocketRocket/LICENSE",
        "third_party/FImmutableSortedDictionary/LICENSE",
        "third_party/SocketRocket/aa2297808c225710e267afece4439c256f6efdb3",
      ],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ],
      linkerSettings: [
        .linkedFramework("CFNetwork"),
        .linkedFramework("Security"),
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
        .linkedFramework("WatchKit", .when(platforms: [.watchOS])),
      ]
    ),
    .testTarget(
      name: "DatabaseUnit",
      dependencies: ["FirebaseDatabase", "OCMock", "SharedTestUtilities"],
      path: "FirebaseDatabase/Tests/",
      exclude: [
        // Disable Swift tests as mixed targets are not supported (Xcode 12.4).
        "Unit/Swift",
        "Integration/",
      ],
      resources: [.process("Resources")],
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .testTarget(
      name: "DatabaseUnitSwift",
      dependencies: ["FirebaseDatabase"],
      path: "FirebaseDatabase/Tests/Unit/Swift",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .target(
      name: "FirebaseDatabaseSwift",
      dependencies: ["FirebaseDatabase", "FirebaseSharedSwift"],
      path: "FirebaseDatabaseSwift/Sources"
    ),
    .testTarget(
      name: "FirebaseDatabaseSwiftTests",
      dependencies: ["FirebaseDatabase", "FirebaseDatabaseSwift"],
      path: "FirebaseDatabaseSwift/Tests/"
    ),
    .target(
      name: "FirebaseSharedSwift",
      path: "FirebaseSharedSwift/Sources",
      exclude: [
        "third_party/FirebaseDataEncoder/LICENSE",
        "third_party/FirebaseDataEncoder/METADATA",
      ]
    ),
    .testTarget(
      name: "FirebaseSharedSwiftTests",
      dependencies: ["FirebaseSharedSwift"],
      path: "FirebaseSharedSwift/Tests/"
    ),
    .target(
      name: "FirebaseDynamicLinksTarget",
      dependencies: [.target(name: "FirebaseDynamicLinks",
                             condition: .when(platforms: [.iOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseDynamicLinksWrap"
    ),

    .target(
      name: "FirebaseDynamicLinks",
      dependencies: ["FirebaseCore"],
      path: "FirebaseDynamicLinks/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRDynamicLinks3P", to: "1"),
        .define("GIN_SCION_LOGGING", to: "1"),
      ],
      linkerSettings: [
        .linkedFramework("QuartzCore"),
      ]
    ),

    .target(
      name: "FirebaseFirestoreTarget",
      dependencies: [.target(name: "FirebaseFirestore",
                             condition: .when(platforms: [.iOS, .tvOS, .macOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseFirestoreWrap"
    ),

    .target(
      name: "FirebaseFirestore",
      dependencies: [
        "FirebaseCore",
        "leveldb",
        .product(name: "nanopb", package: "nanopb"),
        .product(name: "abseil", package: "abseil"),
        .product(name: "gRPC-cpp", package: "gRPC"),
      ],
      path: "Firestore",
      exclude: [
        "CHANGELOG.md",
        "CMakeLists.txt",
        "Example/",
        "LICENSE",
        "Protos/CMakeLists.txt",
        "Protos/Podfile",
        "Protos/README.md",
        "Protos/build_protos.py",
        "Protos/cpp/",
        "Protos/lib/",
        "Protos/nanopb_cpp_generator.py",
        "Protos/protos/",
        "README.md",
        "Source/CMakeLists.txt",
        "Swift/",
        "core/CMakeLists.txt",
        "core/src/util/config_detected.h.in",
        "core/test/",
        "fuzzing/",
        "test.sh",
        // Swift PM doesn't recognize hpp files, so we're relying on search paths
        // to find third_party/nlohmann_json/json.hpp.
        "third_party/",

        // Exclude alternate implementations for other platforms
        "core/src/remote/connectivity_monitor_noop.cc",
        "core/src/util/filesystem_win.cc",
        "core/src/util/log_stdio.cc",
        "core/src/util/secure_random_openssl.cc",
      ],
      sources: [
        "Source/",
        "Protos/nanopb/",
        "core/include/",
        "core/src",
      ],
      publicHeadersPath: "Source/Public",
      cSettings: [
        .headerSearchPath("../"),
        .headerSearchPath("Source/Public/FirebaseFirestore"),
        .headerSearchPath("Protos/nanopb"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
        .define("FIRFirestore_VERSION", to: firebaseVersion),
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
        .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
        .linkedLibrary("c++"),
      ]
    ),

    .target(
      name: "FirebaseFirestoreSwiftTarget",
      dependencies: [.target(name: "FirebaseFirestoreSwift",
                             condition: .when(platforms: [.iOS, .tvOS, .macOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseFirestoreSwiftWrap"
    ),

    .target(
      name: "FirebaseFirestoreSwift",
      dependencies: ["FirebaseFirestore"],
      path: "Firestore",
      exclude: [
        "CHANGELOG.md",
        "CMakeLists.txt",
        "Example/",
        "LICENSE",
        "Protos/",
        "README.md",
        "Source/",
        "core/",
        "fuzzing/",
        "test.sh",
        "Swift/CHANGELOG.md",
        "Swift/README.md",
        "Swift/Tests/",
        "third_party/nlohmann_json",
        "third_party/FirestoreEncoder/LICENSE",
        "third_party/FirestoreEncoder/METADATA",
      ],
      sources: [
        "Swift/Source/",
        "third_party/FirestoreEncoder/",
      ]
    ),

    // MARK: - Firebase Functions

    .target(
      name: "FirebaseFunctions",
      dependencies: [
        "FirebaseAppCheckInterop",
        "FirebaseAuthInterop",
        "FirebaseCore",
        "FirebaseCoreExtension",
        "FirebaseMessagingInterop",
        "FirebaseSharedSwift",
        .product(name: "GTMSessionFetcherCore", package: "GTMSessionFetcher"),
      ],
      path: "FirebaseFunctions/Sources"
    ),
    .testTarget(
      name: "FirebaseFunctionsUnit",
      dependencies: ["FirebaseFunctions",
                     "FirebaseAppCheckInterop",
                     "FirebaseAuthInterop",
                     "FirebaseMessagingInterop",
                     "SharedTestUtilities"],
      path: "FirebaseFunctions/Tests/Unit",
      cSettings: [
        .headerSearchPath("../../../"),
      ]
    ),
    .testTarget(
      name: "FirebaseFunctionsIntegration",
      dependencies: ["FirebaseFunctions",
                     "SharedTestUtilities"],
      path: "FirebaseFunctions/Tests/Integration"
    ),
    .testTarget(
      name: "FirebaseFunctionsObjCIntegration",
      dependencies: ["FirebaseFunctions",
                     "SharedTestUtilities"],
      path: "FirebaseFunctions/Tests/ObjCIntegration",
      // See https://forums.swift.org/t/importing-swift-libraries-from-objective-c/56730
      exclude: [
        "ObjCPPAPITests.mm",
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseFunctionsCombineSwift",
      dependencies: ["FirebaseFunctions"],
      path: "FirebaseCombineSwift/Sources/Functions"
    ),
    .testTarget(
      name: "FunctionsCombineUnit",
      dependencies: ["FirebaseFunctionsCombineSwift",
                     "SharedTestUtilities"],
      path: "FirebaseFunctions/Tests/CombineUnit"
    ),

    // MARK: - Firebase In App Messaging

    .target(
      name: "FirebaseInAppMessagingTarget",
      dependencies: [
        .target(name: "FirebaseInAppMessaging", condition: .when(platforms: [.iOS, .tvOS])),
      ],
      path: "SwiftPM-PlatformExclude/FirebaseInAppMessagingWrap"
    ),

    .target(
      name: "FirebaseInAppMessaging",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        "FirebaseABTesting",
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
        .target(name: "FirebaseInAppMessaging_iOS", condition: .when(platforms: [.iOS])),
      ],
      path: "FirebaseInAppMessaging/Sources",
      exclude: [
        "DefaultUI/CHANGELOG.md",
        "DefaultUI/README.md",
      ],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),

    .target(
      name: "FirebaseInAppMessaging_iOS",
      path: "FirebaseInAppMessaging/iOS",
      resources: [.process("Resources")]
    ),

    .target(
      name: "FirebaseInAppMessagingSwift",
      dependencies: ["FirebaseInAppMessaging"],
      path: "FirebaseInAppMessaging/Swift/Source"
    ),

    .target(
      name: "FirebaseInstallations",
      dependencies: [
        "FirebaseCore",
        .product(name: "FBLPromises", package: "Promises"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULUserDefaults", package: "GoogleUtilities"),
      ],
      path: "FirebaseInstallations/Source/Library",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../../"),
      ],
      linkerSettings: [
        .linkedFramework("Security"),
      ]
    ),

    .target(
      name: "FirebaseMLModelDownloader",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "GULLogger", package: "GoogleUtilities"),
        "SwiftProtobuf",
      ],
      path: "FirebaseMLModelDownloader/Sources",
      exclude: [
        "proto/firebase_ml_log_sdk.proto",
      ],
      cSettings: [
        .define("FIRMLModelDownloader_VERSION", to: firebaseVersion),
      ]
    ),
    .testTarget(
      name: "FirebaseMLModelDownloaderUnit",
      dependencies: ["FirebaseMLModelDownloader"],
      path: "FirebaseMLModelDownloader/Tests/Unit"
    ),

    .target(
      name: "FirebaseMessaging",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "GULAppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULReachability", package: "GoogleUtilities"),
        .product(name: "GULUserDefaults", package: "GoogleUtilities"),
        .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "FirebaseMessaging/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
      ]
    ),
    // Internal headers only for consuming from Swift.
    .target(
      name: "FirebaseMessagingInterop",
      path: "FirebaseMessaging/Interop",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "MessagingUnit",
      dependencies: ["FirebaseMessaging", "SharedTestUtilities", "OCMock"],
      path: "FirebaseMessaging/Tests/UnitTests",
      exclude: [
        "FIRMessagingContextManagerServiceTest.m", // TODO: Adapt its NSBundle usage to SPM.
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

    .target(
      name: "FirebasePerformanceTarget",
      dependencies: [.target(name: "FirebasePerformance",
                             condition: .when(platforms: [.iOS, .tvOS]))],
      path: "SwiftPM-PlatformExclude/FirebasePerformanceWrap"
    ),
    .target(
      name: "FirebasePerformance",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        "FirebaseRemoteConfig",
        .product(name: "GoogleDataTransport", package: "GoogleDataTransport"),
        .product(name: "GULEnvironment", package: "GoogleUtilities"),
        .product(name: "GULISASwizzler", package: "GoogleUtilities"),
        .product(name: "GULMethodSwizzler", package: "GoogleUtilities"),
        .product(name: "GULUserDefaults", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "FirebasePerformance/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
        .define("FIRPerformance_LIB_VERSION", to: firebaseVersion),
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .tvOS])),
        .linkedFramework("MobileCoreServices", .when(platforms: [.iOS, .tvOS])),
        .linkedFramework("QuartzCore", .when(platforms: [.iOS, .tvOS])),
      ]
    ),
    .testTarget(
      name: "PerformanceUnit",
      dependencies: [
        "FirebasePerformanceTarget",
        "OCMock",
        "SharedTestUtilities",
        "GCDWebServer",
      ],
      path: "FirebasePerformance/Tests/Unit",
      resources: [
        .process("FPRURLFilterTests-Info.plist"),
        .process("Server/smallDownloadFile"),
        .process("Server/bigDownloadFile"),
      ],
      cSettings: [
        .headerSearchPath("../../.."),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),

    .target(
      name: "SharedTestUtilities",
      dependencies: ["FirebaseCore",
                     "FirebaseAppCheckInterop",
                     "FirebaseAuthInterop",
                     "FirebaseMessagingInterop",
                     "OCMock"],
      path: "SharedTestUtilities",
      publicHeadersPath: "./",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),

    // MARK: - Firebase Remote Config

    .target(
      name: "FirebaseRemoteConfig",
      dependencies: [
        "FirebaseCore",
        "FirebaseABTesting",
        "FirebaseInstallations",
        .product(name: "GULNSData", package: "GoogleUtilities"),
      ],
      path: "FirebaseRemoteConfig/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "RemoteConfigUnit",
      dependencies: ["FirebaseRemoteConfig", "OCMock"],
      path: "FirebaseRemoteConfig/Tests/Unit",
      exclude: [
        // Need to be evaluated/ported to RC V2.
        "RCNConfigAnalyticsTest.m",
        "RCNConfigSettingsTest.m",
        "RCNConfigTest.m",
        "RCNRemoteConfig+FIRAppTest.m",
        "RCNThrottlingTests.m",
      ],
      resources: [
        .process("SecondApp-GoogleService-Info.plist"),
        .process("Defaults-testInfo.plist"),
        .process("TestABTPayload.txt"),
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseRemoteConfigSwift",
      dependencies: [
        "FirebaseRemoteConfig",
        "FirebaseSharedSwift",
      ],
      path: "FirebaseRemoteConfigSwift/Sources"
    ),
    .testTarget(
      name: "RemoteConfigFakeConsole",
      dependencies: ["FirebaseRemoteConfigSwift",
                     "RemoteConfigFakeConsoleObjC"],
      path: "FirebaseRemoteConfigSwift/Tests",
      exclude: [
        "AccessToken.json",
        "README.md",
        "ObjC/",
      ],
      resources: [
        .process("Defaults-testInfo.plist"),
      ],
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "RemoteConfigFakeConsoleObjC",
      dependencies: ["OCMock"],
      path: "FirebaseRemoteConfigSwift/Tests/ObjC",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../../"),
      ]
    ),

    // MARK: - Firebase Storage

    .target(
      name: "FirebaseStorageInternal",
      dependencies: [
        "FirebaseCore",
        .product(name: "GTMSessionFetcherCore", package: "GTMSessionFetcher"),
      ],
      path: "FirebaseStorageInternal/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ],
      linkerSettings: [
        .linkedFramework("MobileCoreServices", .when(platforms: [.iOS])),
        .linkedFramework("CoreServices", .when(platforms: [.macOS])),
      ]
    ),
    .testTarget(
      name: "StorageUnit",
      dependencies: ["FirebaseStorageInternal", "OCMock", "SharedTestUtilities"],
      path: "FirebaseStorageInternal/Tests/Unit",
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseStorage",
      dependencies: [
        "FirebaseAppCheckInterop",
        "FirebaseAuthInterop",
        "FirebaseCore",
        "FirebaseCoreExtension",
        "FirebaseStorageInternal",
      ],
      path: "FirebaseStorage/Sources"
    ),
    .testTarget(
      name: "FirebaseStorageUnit",
      dependencies: ["FirebaseStorage",
                     "SharedTestUtilities"],
      path: "FirebaseStorage/Tests/Unit",
      cSettings: [
        .headerSearchPath("../../../"),
      ]
    ),
    .testTarget(
      name: "StorageObjcIntegration",
      dependencies: ["FirebaseStorage"],
      path: "FirebaseStorage/Tests/ObjcIntegration",
      exclude: [
        // See https://forums.swift.org/t/importing-swift-libraries-from-objective-c/56730
        "ObjCPPAPITests.mm",
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .testTarget(
      name: "swift-test",
      dependencies: [
        "Firebase",
        "FirebaseAuth",
        "FirebaseAppCheck",
        "FirebaseABTesting",
        "FirebaseAnalytics",
        "FirebaseAnalyticsSwift",
        .target(name: "FirebaseAppDistribution",
                condition: .when(platforms: [.iOS])),
        "FirebaseAuthCombineSwift",
        "FirebaseFirestoreCombineSwift",
        "FirebaseFunctionsCombineSwift",
        "FirebaseStorageCombineSwift",
        "FirebaseCrashlytics",
        "FirebaseCore",
        "FirebaseDatabase",
        "FirebaseDynamicLinks",
        "FirebaseFirestore",
        "FirebaseFirestoreSwift",
        "FirebaseFunctions",
        "FirebaseInAppMessaging",
        .target(name: "FirebaseInAppMessagingSwift",
                condition: .when(platforms: [.iOS, .tvOS])),
        "FirebaseInstallations",
        "FirebaseMessaging",
        .target(name: "FirebasePerformance",
                condition: .when(platforms: [.iOS, .tvOS])),
        "FirebaseRemoteConfig",
        "FirebaseStorage",
        "FirebaseStorageInternal",
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "SwiftPMTests/swift-test"
    ),
    .testTarget(
      name: "analytics-import-test",
      dependencies: [
        "FirebaseAnalyticsSwiftTarget",
        "FirebaseAnalyticsWrapper",
        "Firebase",
      ],
      path: "SwiftPMTests/analytics-import-test"
    ),
    .testTarget(
      name: "objc-import-test",
      dependencies: [
        "Firebase",
        "FirebaseAuth",
        "FirebaseABTesting",
        "FirebaseAppCheck",
        .target(name: "FirebaseAppDistribution",
                condition: .when(platforms: [.iOS])),
        "FirebaseCrashlytics",
        "FirebaseCore",
        "FirebaseDatabase",
        "FirebaseDynamicLinks",
        "FirebaseFirestore",
        "FirebaseFunctions",
        "FirebaseInAppMessaging",
        "FirebaseInstallations",
        "FirebaseMessaging",
        .target(name: "FirebasePerformance",
                condition: .when(platforms: [.iOS, .tvOS])),
        "FirebaseRemoteConfig",
        "FirebaseStorage",
      ],
      path: "SwiftPMTests/objc-import-test"
    ),
    .testTarget(
      name: "version-test",
      dependencies: [
        "FirebaseCore",
      ],
      path: "SwiftPMTests/version-test",
      cSettings: [
        .define("FIR_VERSION", to: firebaseVersion),
      ]
    ),

    // MARK: - Firebase App Check

    .target(name: "FirebaseAppCheck",
            dependencies: [
              "FirebaseCore",
              .product(name: "FBLPromises", package: "Promises"),
              .product(name: "GULEnvironment", package: "GoogleUtilities"),
            ],
            path: "FirebaseAppCheck/Sources",
            publicHeadersPath: "Public",
            cSettings: [
              .headerSearchPath("../.."),
            ],
            linkerSettings: [
              .linkedFramework("DeviceCheck", .when(platforms: [.iOS, .macOS, .tvOS])),
            ]),
    // Internal headers only for consuming from Swift.
    .target(
      name: "FirebaseAppCheckInterop",
      path: "FirebaseAppCheck/Interop",
      exclude: [
        "CMakeLists.txt",
      ],
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "AppCheckUnit",
      dependencies: [
        "FirebaseAppCheck",
        "OCMock",
        "SharedTestUtilities",
        "HeartbeatLoggingTestUtils",
      ],
      path: "FirebaseAppCheck/Tests",
      exclude: [
        // Disable Swift tests as mixed targets are not supported (Xcode 12.3).
        "Unit/Swift",
      ],
      resources: [
        .process("Fixture"),
      ],
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .testTarget(
      name: "AppCheckUnitSwift",
      dependencies: ["FirebaseAppCheck"],
      path: "FirebaseAppCheck/Tests/Unit/Swift",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),

    // MARK: Testing support

    .target(
      name: "FirebaseFirestoreTestingSupport",
      dependencies: ["FirebaseFirestore"],
      path: "FirebaseTestingSupport/Firestore/Sources",
      publicHeadersPath: "./",
      cSettings: [
        .headerSearchPath("../../.."),
        .headerSearchPath("../../../Firestore/Source/Public/FirebaseFirestore"),
      ]
    ),
    .testTarget(
      name: "FirestoreTestingSupportTests",
      dependencies: ["FirebaseFirestoreTestingSupport"],
      path: "FirebaseTestingSupport/Firestore/Tests",
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

  ],
  cLanguageStandard: .c99,
  cxxLanguageStandard: CXXLanguageStandard.gnucxx14
)

if ProcessInfo.processInfo.environment["FIREBASECI_USE_LATEST_GOOGLEAPPMEASUREMENT"] != nil {
  if let GoogleAppMeasurementIndex = package.dependencies
    .firstIndex(where: { $0.name == "GoogleAppMeasurement" }) {
    package.dependencies[GoogleAppMeasurementIndex] = .package(
      name: "GoogleAppMeasurement",
      url: "https://github.com/google/GoogleAppMeasurement.git",
      .branch("main")
    )
  }
}
