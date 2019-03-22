// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Metrics",
  dependencies: [
    .package(url: "https://github.com/objecthub/swift-commandlinekit", from: "0.2.5"),
  ],
  targets: [
    .target(
      name: "MetricsLib"
    ),
    .target(
      name: "Metrics",
      dependencies: ["CommandLineKit", "MetricsLib"]
    ),
    .testTarget(
      name: "MetricsTests",
      dependencies: ["MetricsLib"]
    ),
  ]
)
