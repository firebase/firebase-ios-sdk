// swift-tools-version: 5.8
//In Package Manifest

import PackageDescription

let package = Package(
    name: "CxxInterop",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "CxxTest",
            targets: ["CxxTest"]),
        .executable(
            name: "CxxInterop",
            targets: ["CxxInterop"]),
    ],
    targets: [
        .target(
            name: "CxxTest",
            dependencies: []
        ),
        .executableTarget(
            name: "CxxInterop",
            dependencies: ["CxxTest"],
            path: "./Sources/CxxInterop",
            sources: [ "main.swift" ],
            swiftSettings: [.unsafeFlags([
                "-I", "Sources/CxxTest",
                "-enable-experimental-cxx-interop",
            ])]
        ),
    ]
)
