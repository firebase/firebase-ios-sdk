// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Firebase",
  platforms: [.iOS(.v9), .macOS(.v10_11), .tvOS(.v10)],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to
    // other packages.
    // This is a test-only executable for us to try `swift run` and use all imported modules from a
    // Swift target.
    .executable(name: "firebase-test", targets: ["firebase-test"]),
    //
    .library(
      name: "GoogleUtilities_AppDelegateSwizzler",
      targets: ["GoogleUtilities_AppDelegateSwizzler"]
    ),
    .library(
      name: "GoogleUtilities_Environment",
      targets: ["GoogleUtilities_Environment"]
    ),
    .library(
      name: "GoogleUtilities_Logger",
      targets: ["GoogleUtilities_Logger"]
    ),
    .library(
      name: "Firebase",
      targets: ["Firebase"]
    ),
    .library(
      name: "FirebaseCore",
      type: .static, // Seems to always be dynamic for macOS and always static for iOS whether this is set or not
      targets: ["FirebaseCore"]
    ),
    .library(
      name: "FirebaseAuth",
      type: .static,
      targets: ["FirebaseAuth"]
    ),
    .library(
      name: "FirebaseFunctions",
      type: .static,
      targets: ["FirebaseFunctions"]
    ),
    .library(
      name: "FirebaseInstanceID",
      type: .static,
      targets: ["FirebaseInstanceID"]
    ),
    .library(
      name: "FirebaseStorage",
      type: .static,
      targets: ["FirebaseStorage"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/paulb777/gtm-session-fetcher.git", .branch("spm2")),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "firebase-test",
      dependencies: ["Firebase", "FirebaseCore", "FirebaseAuth", "FirebaseFunctions", "FirebaseInstanceID",
                     "FirebaseStorage", "GoogleUtilities_AppDelegateSwizzler",
                     "GoogleUtilities_Environment", "GoogleUtilities_Logger"]
    ),
    .target(
      name: "GoogleUtilities_AppDelegateSwizzler",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger", "GoogleUtilities_Network"],
      path: "GoogleUtilities/AppDelegateSwizzler",
      cSettings: [
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Network/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/AppDelegateSwizzler/Private"),
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults when loaded into an Xcode project
      ]
    ),
    .target(
      name: "GoogleUtilities_Environment",
      path: "GoogleUtilities/Environment/third_party",
      sources: ["GULAppEnvironmentUtil.m"],
      publicHeadersPath: "."
    ),
    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults when loaded into an Xcode project
      ]
    ),
    .target(
      name: "GoogleUtilities_Network",
      dependencies: ["GoogleUtilities_Logger", "GoogleUtilities_NSData", "GoogleUtilities_Reachability"],
      path: "GoogleUtilities/Network",
      cSettings: [
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/NSData+zlib"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Reachability/Private"),
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults when loaded into an Xcode project
      ],
      linkerSettings: [
        .linkedFramework("Security"),
      ]
    ),
    .target(
      name: "GoogleUtilities_NSData",
      path: "GoogleUtilities/NSData+zlib",
      cSettings: [
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults when loaded into an Xcode project
      ],
      linkerSettings: [
        .linkedLibrary("z"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Reachability",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/Reachability",
      cSettings: [
        .headerSearchPath("$(SRCROOT)/GoogleUtilities"),
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Reachability/Private"),
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
      ],
      linkerSettings: [
        .linkedFramework("SystemConfiguration"),
      ]
    ),
    .target(
      name: "GoogleUtilities_UserDefaults",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/UserDefaults",
      publicHeadersPath: "Private", // Consider renaming "Private" directory to "Public"
      cSettings: [
        .headerSearchPath("$(SRCROOT)/GoogleUtilities"),
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/UserDefaults/Private"),
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
      ]
    ),
    // Interop fails with
    // warning: Source files for target FirebaseAuthInterop should be located under ..firebase-ios-sdk/Interop/Auth
    // 'Firebase' : error: target 'FirebaseAuthInterop' referenced in product 'FirebaseAuthInterop' could not be found
//    .target(
//      name: "FirebaseAuthInterop",
//      path: "Interop/Auth",
//      sources: ["Interop/Auth/Public/FIRAuthInterop.h"],
//      publicHeadersPath: "Public"),
    .target(
      name: "Firebase",
      path: "Firebase/Firebase",
      publicHeadersPath: "Public"
    ),
    .target(
      name: "FirebaseCore",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger"],
      path: "Firebase/Core",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("$(SRCROOT)"),
        .headerSearchPath("$(SRCROOT)/Firebase"), // TODO: - remove this in favor of putting Firebase in imports.
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/Logger/Private"), // SPM doesn't support private headers
        .define("FIRCore_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("Firebase_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
        // TODO: - Add support for cflags cSetting so that we can set the -fno-autolink option
      ]
    ),
    .target(
      name: "FirebaseAuth",
      dependencies: ["FirebaseCore", "GoogleUtilities_Environment", "GoogleUtilities_AppDelegateSwizzler",
                     "GTMSessionFetcher_Core"],
      path: "Firebase/Auth",
      publicHeadersPath: "Source/Public",
      cSettings: [
        // SPM doesn't support interface frameworks or private headers
        .headerSearchPath("$(SRCROOT)"),
        .headerSearchPath("$(SRCROOT)/Firebase"),
        .headerSearchPath("$(SRCROOT)/Interop/Auth/Public"),
        .headerSearchPath("$(SRCROOT)/Firebase/Core/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/GoogleUtilities/AppDelegateSwizzler/Private"), // SPM doesn't support private headers
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Public"), // TODO: make Auth imports consistent
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Auth"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/GameCenter"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/Email"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/Google"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/OAuth"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/Phone"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/AuthProvider/Twitter"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Backend"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Backend/RPC"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Storage"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/SystemService"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/User"),
        .headerSearchPath("$(SRCROOT)/Firebase/Auth/Source/Utilities"),
        .define("FIRAuth_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("FIRAuth_MINOR_VERSION", to: "1.1"), // TODO: Fix version
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
      ],
      linkerSettings: [
        .linkedFramework("Security"),
        //  .linkedFramework("SafariServices", .when(platforms: [.iOS])),
      ]
    ),
    .target(
      name: "FirebaseFunctions",
      dependencies: ["FirebaseCore", "GTMSessionFetcher_Core"],
      path: "Functions/FirebaseFunctions",
      publicHeadersPath: "Public",
      cSettings: [
        // SPM doesn't support interface frameworks or private headers
        .headerSearchPath("$(SRCROOT)"),
        .define("FIRFunctions_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
      ]
    ),
    .target(
      name: "FirebaseInstanceID",
      dependencies: ["FirebaseCore", "GoogleUtilities_Environment", "GoogleUtilities_UserDefaults"],
      path: "Firebase/InstanceID",
      publicHeadersPath: "Public",
      cSettings: [
        // SPM doesn't support interface frameworks or private headers
        .headerSearchPath("$(SRCROOT)"),
        .define("FIRInstanceID_LIB_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
      ]
    ),
    .target(
      name: "FirebaseStorage",
      dependencies: ["FirebaseCore", "GTMSessionFetcher_Core"],
      path: "Firebase/Storage",
      publicHeadersPath: "Public",
      cSettings: [
        // SPM doesn't support interface frameworks or private headers
        .headerSearchPath("$(SRCROOT)"),
        .headerSearchPath("$(SRCROOT)/Firebase"),
        .headerSearchPath("$(SRCROOT)/Interop/Auth/Public"),
        .headerSearchPath("$(SRCROOT)/Firebase/Core/Private"), // SPM doesn't support private headers
        .define("FIRStorage_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("SWIFT_PACKAGE", to: "1"), // SPM loses defaults if other cSettings
      ],
      linkerSettings: [
        .linkedFramework("CoreServices", .when(platforms: [.macOS])),
        .linkedFramework("MobileCoreServices", .when(platforms: [.iOS, .tvOS])),
      ]
    ),
  ],
  cLanguageStandard: .c99
)
