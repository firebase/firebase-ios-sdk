// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZipBuilder",
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", .exact("1.2.0"))
    ],
    targets: [
        .target(
            name: "ZipBuilder",
            dependencies: ["SwiftProtobuf"]),
    ]
)
