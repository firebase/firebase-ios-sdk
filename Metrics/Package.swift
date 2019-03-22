// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Metrics",
    dependencies: [
	.package(url: "https://github.com/jatoben/CommandLine", from: "3.0.0-pre1"),
    ],
    targets: [
        .target(
            name: "MetricsLib"),
        .target(
            name: "Metrics",
            dependencies: ["CommandLine", "MetricsLib"]),
        .testTarget(
            name: "MetricsTests",
            dependencies: ["MetricsLib"]),
    ]
)
