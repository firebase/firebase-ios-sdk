// swift-tools-version: 5.8
// In Package Manifest

import PackageDescription

let package = Package(
    name: "CxxInterop",
    platforms: [.macOS(.v12)],
    products: [
        .executable(
            name: "CxxInterop",
            targets: ["CxxInterop"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/nanopb.git",
            "2.30909.0" ..< "2.30910.0"
        ),
        .package(
            url: "https://github.com/google/abseil-cpp-binary.git",
            "1.2022062300.0" ..< "1.2022062400.0"
        ),
        .package(
            url: "https://github.com/google/grpc-binary.git",
            "1.50.1" ..< "1.51.0"
        ),
        .package(
            url: "https://github.com/erikdoe/ocmock.git",
            revision: "c5eeaa6dde7c308a5ce48ae4d4530462dd3a1110"
        ),
        .package(
            url: "https://github.com/firebase/leveldb.git",
            "1.22.2" ..< "1.23.0"
        ),
    ],
    targets: [
        .target(
            name: "CxxTest",
            dependencies: [],
            cSettings: [
              .headerSearchPath("../.."),
      ]
        ),
        .target(
            name: "FirebaseFirestoreTarget",
            dependencies: [
                .target(
                    name: "FirebaseFirestore",
                    condition: .when(platforms: [.iOS, .macCatalyst, .tvOS, .macOS])
                ),
                .product(name: "abseil", package: "abseil-cpp-binary"),
                .product(name: "gRPC-C++", package: "grpc-binary"),
                .product(name: "nanopb", package: "nanopb"),
                "leveldb",
            ],
            path: "Sources/FirebaseFirestoreWrap",
            linkerSettings: [
                .linkedFramework("SystemConfiguration", .when(platforms: [.iOS, .macOS, .tvOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS, .tvOS])),
                .linkedLibrary("c++"),
            ]
        ),
        .binaryTarget(
            name: "FirebaseFirestore",
            url: "https://dl.google.com/firebase/ios/bin/firestore/10.10.0/FirebaseFirestore.zip",
            checksum: "4a0070c4bf7e5ab59359dd8a0e68f402f3ec6c1e189fc39cc44ca88418f26ac4"
        ),
        .executableTarget(
            name: "CxxInterop",
            dependencies: ["CxxTest", "FirebaseFirestoreTarget"],
            path: "./Sources/CxxInterop",
            sources: ["main.swift"],
            swiftSettings: [.unsafeFlags([
                "-I", "Sources/CxxTest",
                "-enable-experimental-cxx-interop",
            ])]
        ),
    ]
)
