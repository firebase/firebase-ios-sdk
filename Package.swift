// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Firebase",
  platforms: [ .iOS(.v9), .macOS(.v10_11), .tvOS(.v10) ],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to
    // other packages.
    // This is a test-only executable for us to try `swift run` and use all imported modules from a
    // Swift target.
    .executable(name: "firebase-test", targets: ["firebase-test"]),
    //
    .library(
      name: "GoogleUtilities_Environment",
      targets: ["GoogleUtilities_Environment"]),
    .library(
      name: "GoogleUtilities_Logger",
      targets: ["GoogleUtilities_Logger"]),
    .library(
      name: "FirebaseCore",
      type: .static, // TODO - investigate why this still builds a dynamic library
      targets: ["FirebaseCore"]),
    .library(
      name: "FirebaseStorage",
      type: .static, // TODO - investigate why this still builds a dynamic library
      targets: ["FirebaseStorage"]),
  ],
  dependencies: [
    .package(url: "https://github.com/paulb777/gtm-session-fetcher.git", .branch("spm2")),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "firebase-test",
      dependencies: ["FirebaseCore", "FirebaseStorage", "GoogleUtilities_Environment", "GoogleUtilities_Logger"]
    ),
    .target(
      name: "GoogleUtilities_Environment",
      path: "GoogleUtilities/Environment/third_party",
      sources: ["GULAppEnvironmentUtil.m"],
      publicHeadersPath: "."),
    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .define("SWIFT_PACKAGE", to: "1"),  // SPM loses defaults when loaded into an Xcode project
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
      ]
      ),
// Interop fails with
// warning: Source files for target FirebaseAuthInterop should be located under ..firebase-ios-sdk/Interop/Auth
//'Firebase' : error: target 'FirebaseAuthInterop' referenced in product 'FirebaseAuthInterop' could not be found
//    .target(
//      name: "FirebaseAuthInterop",
//      path: "Interop/Auth",
//      sources: ["Interop/Auth/Public/FIRAuthInterop.h"],
//      publicHeadersPath: "Public"),
    .target(
      name: "FirebaseCore",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger"],
      path: "Firebase/Core",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("$(SRCROOT)/Firebase"),
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .define("FIRCore_VERSION", to: "0.0.1"),  // TODO Fix version
        .define("Firebase_VERSION", to: "0.0.1"),  // TODO Fix version
        .define("SWIFT_PACKAGE", to: "1"),  // SPM loses defaults if other cSettings
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
// TODO - Add support for cflags cSetting so that we can set the -fno-autolink option
      ]),
    .target(
      name: "FirebaseStorage",
      dependencies: ["FirebaseCore", "GTMSessionFetcher_Core"],
      path: "Firebase/Storage",
      publicHeadersPath: "Public",
      cSettings: [
         // SPM doesn't support interface frameworks or private headers
        .headerSearchPath("$(SRCROOT)/Firebase"),
        .headerSearchPath("$(SRCROOT)/Interop/Auth/Public"),
        .headerSearchPath("$(SRCROOT)/Firebase/Core/Private"), // SPM doesn't support private headers
        .define("FIRStorage_VERSION", to: "0.0.1"),  // TODO Fix version
        .define("SWIFT_PACKAGE", to: "1"),  // SPM loses defaults if other cSettings
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
      ],
      linkerSettings: [
        .linkedFramework("CoreServices", .when(platforms: [.macOS])),
        .linkedFramework("MobileCoreServices", .when(platforms: [.iOS, .tvOS])),
      ])
  ],
  cLanguageStandard: .c99
)
