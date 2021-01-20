// swift-tools-version:5.3
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

// This Package.swift is a Work in Progress. We intend to keep it functional
// on the master branch, but it is rapidly evolving and may have occasional
// breakages. Please report any issues at
// https://github.com/firebase/firebase-ios-sdk/issues/new/choose.

import PackageDescription

let firebaseVersion = "7.4.0"

let package = Package(
  name: "Firebase",
  platforms: [.iOS(.v10), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v6)],
  products: [
    .library(
      name: "FirebaseAnalytics",
      targets: ["FirebaseAnalyticsTarget"]
    ),
    .library(
      name: "FirebaseAuth",
      targets: ["FirebaseAuth"]
    ),
    .library(
      name: "FirebaseAppDistribution-Beta",
      targets: ["FirebaseAppDistributionTarget"]
    ),
    .library(
      name: "FirebaseCrashlytics",
      targets: ["FirebaseCrashlytics"]
    ),
    .library(
      name: "FirebaseDatabase",
      targets: ["FirebaseDatabaseTarget"]
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
      name: "FirebaseFirestoreSwift-Beta",
      targets: ["FirebaseFirestoreSwiftTarget"]
    ),
    .library(
      name: "FirebaseFunctions",
      targets: ["FirebaseFunctionsTarget"]
    ),
    .library(
      name: "FirebaseInAppMessaging-Beta",
      targets: ["FirebaseInAppMessagingTarget"]
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
      name: "FirebaseRemoteConfig",
      targets: ["FirebaseRemoteConfigTarget"]
    ),
    .library(
      name: "FirebaseStorage",
      targets: ["FirebaseStorage"]
    ),
    .library(
      name: "FirebaseStorageSwift-Beta",
      targets: ["FirebaseStorageSwift"]
    ),
  ],
  dependencies: [
    .package(name: "Promises", url: "https://github.com/google/promises.git", "1.2.8" ..< "1.3.0"),
    .package(
      name: "SwiftProtobuf",
      url: "https://github.com/apple/swift-protobuf.git",
      from: "1.14.0"
    ),
    .package(
      name: "GoogleAppMeasurement",
      url: "https://github.com/google/GoogleAppMeasurement.git",
      from: "7.4.0"
    ),
    .package(
      name: "GoogleUtilities",
      url: "https://github.com/google/GoogleUtilities.git",
      "7.2.0" ..< "8.0.0"
    ),
    .package(
      name: "GTMSessionFetcher",
      url: "https://github.com/google/gtm-session-fetcher.git",
      "1.4.0" ..< "2.0.0"
    ),
    .package(
      name: "nanopb",
      url: "https://github.com/firebase/nanopb.git",
      // This revision adds SPM enablement to the 0.3.9.6 release tag.
      "2.30907.0" ..< "2.30908.0"
    ),
    .package(name: "abseil",
             url: "https://github.com/firebase/abseil-cpp-SwiftPM.git",
             from: "0.20200225.0"),
    .package(
      name: "gRPC",
      url: "https://github.com/firebase/grpc-SwiftPM.git",
      "1.28.2" ..< "1.29.0"
    ),
    .package(
      name: "OCMock",
      url: "https://github.com/firebase/ocmock.git",
      .revision("7291762d3551c5c7e31c49cce40a0e391a52e889")
    ),
    .package(
      name: "leveldb",
      url: "https://github.com/firebase/leveldb.git",
      "1.22.1" ..< "1.23.0"
    ),
    // Branches need a force update with a run with the revision set like below.
    //   .package(url: "https://github.com/paulb777/nanopb.git", .revision("564392bd87bd093c308a3aaed3997466efb95f74"))
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
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "Logger", package: "GoogleUtilities"),
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
      dependencies: ["FirebaseCore", "SharedTestUtilities", "OCMock"],
      path: "FirebaseCore/Tests/Unit",
      exclude: ["Resources/GoogleService-Info.plist"],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseCoreDiagnostics",
      dependencies: [
        "GoogleDataTransport",
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "Logger", package: "GoogleUtilities"),
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
                             condition: .when(platforms: [.iOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseAnalyticsWrap"
    ),

    .target(
      name: "FirebaseAnalyticsWrapper",
      dependencies: [
        .target(name: "FirebaseAnalytics", condition: .when(platforms: [.iOS])),
        .product(name: "GoogleAppMeasurement",
                package: "GoogleAppMeasurement",
                condition: .when(platforms: [.iOS])),
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "AppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "MethodSwizzler", package: "GoogleUtilities"),
        .product(name: "NSData", package: "GoogleUtilities"),
        .product(name: "Network", package: "GoogleUtilities"),
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
      url: "https://dl.google.com/firebase/ios/swiftpm/7.4.0/FirebaseAnalytics.zip",
      checksum: "560bf11462c9e064c0d55e10aef761af420f4f531415e896cac18edc88e9666f"
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
        "GoogleDataTransport",
        .product(name: "AppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "UserDefaults", package: "GoogleUtilities"),
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
      resources: [.process("Resources")],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

    .target(
      name: "FirebaseAuth",
      dependencies: [
        "FirebaseCore",
        .product(name: "AppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "Environment", package: "GoogleUtilities"),
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
    .testTarget(
      name: "AuthUnit",
      dependencies: ["FirebaseAuth", "OCMock"],
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
      name: "FirebaseCrashlytics",
      dependencies: ["FirebaseCore", "FirebaseInstallations", "GoogleDataTransport",
                     .product(name: "FBLPromises", package: "Promises"),
                     .product(name: "nanopb", package: "nanopb")],
      path: "Crashlytics",
      exclude: [
        "run",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "Data/",
        "Protos/",
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
      name: "FirebaseDatabaseTarget",
      dependencies: [.target(name: "FirebaseDatabase",
                             condition: .when(platforms: [.iOS, .tvOS, .macOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseDatabaseWrap"
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
      ]
    ),
    .testTarget(
      name: "DatabaseUnit",
      dependencies: ["FirebaseDatabase", "OCMock", "SharedTestUtilities"],
      path: "FirebaseDatabase/Tests/",
      exclude: [
        "Integration/",
      ],
      resources: [.process("Resources")],
      cSettings: [
        .headerSearchPath("../.."),
      ]
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
        "third_party/",

        // Exclude alternate implementations for other platforms
        "core/src/api/input_validation_std.cc",
        "core/src/remote/connectivity_monitor_noop.cc",
        "core/src/util/filesystem_win.cc",
        "core/src/util/hard_assert_stdio.cc",
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
        "Protos/",
        "README.md",
        "Source/",
        "core/",
        "fuzzing/",
        "test.sh",
        "Swift/CHANGELOG.md",
        "Swift/README.md",
        "Swift/Tests/",
        "third_party/FirestoreEncoder/LICENSE",
        "third_party/FirestoreEncoder/METADATA",
      ],
      sources: [
        "Swift/Source/",
        "third_party/FirestoreEncoder/",
      ]
    ),

    .target(
      name: "FirebaseFunctionsTarget",
      dependencies: [.target(name: "FirebaseFunctions",
                             condition: .when(platforms: [.iOS, .tvOS, .macOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseFunctionsWrap"
    ),

    .target(
      name: "FirebaseFunctions",
      dependencies: [
        "FirebaseCore",
        .product(name: "GTMSessionFetcherCore", package: "GTMSessionFetcher"),
      ],
      path: "Functions/FirebaseFunctions",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "FirebaseInAppMessagingTarget",
      dependencies: [.target(name: "FirebaseInAppMessaging",
                             condition: .when(platforms: [.iOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseInAppMessagingWrap"
    ),

    .target(
      name: "FirebaseInAppMessaging",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        "FirebaseABTesting",
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "FirebaseInAppMessaging/Sources",
      exclude: [
        "DefaultUI/CHANGELOG.md",
        "DefaultUI/README.md",
      ],
      resources: [.process("Resources")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),

    .target(
      name: "FirebaseInstanceID",
      dependencies: [
        "FirebaseCore",
        "FirebaseInstallations",
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "UserDefaults", package: "GoogleUtilities"),
      ],
      path: "Firebase/InstanceID",
      exclude: [
        "CHANGELOG.md",
      ],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "FirebaseInstallations",
      dependencies: [
        "FirebaseCore",
        .product(name: "FBLPromises", package: "Promises"),
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "UserDefaults", package: "GoogleUtilities"),
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
        "FirebaseInstanceID",
        .product(name: "AppDelegateSwizzler", package: "GoogleUtilities"),
        .product(name: "Environment", package: "GoogleUtilities"),
        .product(name: "Reachability", package: "GoogleUtilities"),
        .product(name: "UserDefaults", package: "GoogleUtilities"),
      ],
      path: "FirebaseMessaging/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
      ]
    ),
    .testTarget(
      name: "MessagingUnit",
      dependencies: ["FirebaseMessaging", "OCMock"],
      path: "FirebaseMessaging/Tests/UnitTests",
      exclude: [
        "FIRMessagingContextManagerServiceTest.m", // TODO: Adapt its NSBundle usage to SPM.
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),

    .target(
      name: "SharedTestUtilities",
      dependencies: ["FirebaseCore", "OCMock"],
      path: "SharedTestUtilities",
      publicHeadersPath: "./",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),

    .target(
      name: "FirebaseRemoteConfigTarget",
      dependencies: [.target(name: "FirebaseRemoteConfig",
                             condition: .when(platforms: [.iOS, .tvOS, .macOS]))],
      path: "SwiftPM-PlatformExclude/FirebaseRemoteConfigWrap"
    ),

    .target(
      name: "FirebaseRemoteConfig",
      dependencies: [
        "FirebaseCore",
        "FirebaseABTesting",
        "FirebaseInstallations",
        .product(name: "NSData", package: "GoogleUtilities"),
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
      name: "FirebaseStorage",
      dependencies: [
        "FirebaseCore",
        .product(name: "GTMSessionFetcherCore", package: "GTMSessionFetcher"),
      ],
      path: "FirebaseStorage/Sources",
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
      dependencies: ["FirebaseStorage", "OCMock", "SharedTestUtilities"],
      path: "FirebaseStorage/Tests/Unit",
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
    .target(
      name: "FirebaseStorageSwift",
      dependencies: ["FirebaseStorage"],
      path: "FirebaseStorageSwift/Sources"
    ),
    .target(
      name: "GoogleDataTransport",
      dependencies: [
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "GoogleDataTransport",
      exclude: [
        "CHANGELOG.md",
        "README.md",
        "generate_project.sh",
        "GDTCCTWatchOSTestApp/",
        "GDTWatchOSTestApp/",
        "GDTCCTTestApp/",
        "GDTTestApp/",
        "GDTCCTTests/",
        "GDTCORTests/",
        "ProtoSupport/",
      ],
      sources: [
        "GDTCORLibrary",
        "GDTCCTLibrary",
      ],
      publicHeadersPath: "GDTCORLibrary/Public",
      cSettings: [
        .headerSearchPath("../"),
        .define("GDTCOR_VERSION", to: "0.0.1"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
        .linkedFramework("CoreTelephony", .when(platforms: [.macOS, .iOS])),
      ]
    ),
    .testTarget(
      name: "swift-test",
      dependencies: [
        "FirebaseAuth",
        "FirebaseABTesting",
        .target(name: "FirebaseAppDistribution",
                condition: .when(platforms: [.iOS])),
        "Firebase",
        "FirebaseCrashlytics",
        "FirebaseCore",
        "FirebaseDatabase",
        "FirebaseDynamicLinks",
        "FirebaseFirestore",
        "FirebaseFirestoreSwift",
        "FirebaseFunctions",
        "FirebaseInAppMessaging",
        "FirebaseInstallations",
        "FirebaseMessaging",
        "FirebaseRemoteConfig",
        "FirebaseStorage",
        "FirebaseStorageSwift",
        "GoogleDataTransport",
        .product(name: "nanopb", package: "nanopb"),
      ],
      path: "SwiftPMTests/swift-test"
    ),
    .testTarget(
      name: "analytics-import-test",
      dependencies: [
        "FirebaseAnalyticsWrapper",
        "Firebase",
      ],
      path: "SwiftPMTests/analytics-import-test"
    ),
    .testTarget(
      name: "objc-import-test",
      dependencies: [
        "FirebaseAuth",
        "FirebaseABTesting",
        .target(name: "FirebaseAppDistribution",
                condition: .when(platforms: [.iOS])),
        "Firebase",
        "FirebaseCrashlytics",
        "FirebaseCore",
        "FirebaseDatabase",
        "FirebaseDynamicLinks",
        "FirebaseFirestore",
        "FirebaseFunctions",
        "FirebaseInAppMessaging",
        "FirebaseInstallations",
        "FirebaseMessaging",
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
  ],
  cLanguageStandard: .c99,
  cxxLanguageStandard: CXXLanguageStandard.gnucxx14
)
