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
  ],
  dependencies: [
    // Dependencies declare other external packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "firebase-test",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger"]
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
      publicHeadersPath: "Public")
  ]
)
