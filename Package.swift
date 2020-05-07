// swift-tools-version:5.2
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
   // .executable(name: "firebase-test", targets: ["firebase-test"]),
    //
    .library(
      name: "GoogleUtilities_Environment",
      targets: ["GoogleUtilities_Environment"])
//    .library(
//      name: "GoogleUtilities_Logger",
//      targets: ["GoogleUtilities_Logger"])
    /*
    .library(
      name: "GoogleUtilities_AppDelegateSwizzler",
      targets: ["GoogleUtilities_AppDelegateSwizzler"]),
    .library(
      name: "GoogleUtilities_Logger",
      targets: ["GoogleUtilities_Logger"])
 */
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    /*
    .target(
      name: "firebase-test",
      dependencies: [ "GoogleUtilities_AppDelegateSwizzler", "GoogleUtilities_Environment", "GoogleUtilities_Logger"]
    ),
    .target(
      name: "GoogleUtilities_AppDelegateSwizzler",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger", "GoogleUtilities_Network"],
      path: "GoogleUtilities/AppDelegateSwizzler",
      cSettings: [
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Network/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/AppDelegateSwizzler/Private"),
        .define("SWIFT_PACKAGE", to: "1"),  // SPM loses defaults when loaded into an Xcode project
      ]
    ),
 */
    .target(
      name: "GoogleUtilities_Environment",
      path: "GoogleUtilities/Environment/third_party",
      sources: ["GULAppEnvironmentUtil.m"],
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../../..") // Root of the repo, needed for Firebase's absolute filepaths.
    ]),
    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../..") // Root of the repo, needed for Firebase's absolute filepaths.
      ]
    ),
    .target(
      name: "GoogleUtilities_NSData",
      path: "GoogleUtilities/NSData+zlib",
      publicHeadersPath: ".", // All headers are public (there's only one).
      cSettings: [
        .headerSearchPath("../..") // Root of the repo, needed for Firebase's absolute filepaths.
      ],
      linkerSettings: [
        .linkedLibrary("z"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Reachability",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/Reachability",
      // We need to expose the private internal headers as public.
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../..") // Root of the repo, needed for Firebase's absolute filepaths.
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Network",
      dependencies: ["GoogleUtilities_Logger", "GoogleUtilities_NSData", "GoogleUtilities_Reachability"],
      path: "GoogleUtilities/Network",
      cSettings: [
        .headerSearchPath("../..") // Root of the repo, needed for Firebase's absolute filepaths.
      ],
      linkerSettings: [
        .linkedFramework("Security"),
      ]
    ),
    .target(
      name: "GoogleUtilities_UserDefaults",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/UserDefaults",
      publicHeadersPath: "Private", // Consider renaming "Private" directory to "Public"
      cSettings: [
        .headerSearchPath("../..") // Root of the repo, needed for Firebase's absolute filepaths.
      ]
    )
  ],
  cLanguageStandard: .c99
)
