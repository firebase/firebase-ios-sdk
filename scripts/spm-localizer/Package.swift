// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "FirebaseSDKScripts",
    platforms: [.macOS(.v10_11)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "SPMLocalize",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: ".",
            sources: ["spm_localize_xcode_project.swift"]
        )
    ]
)
