/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Testing
@testable import ZipBuilder

struct ConfigTests {
  /// Writes `json` to a temporary file and loads it.
  private func load(_ json: String) throws -> Config {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip_builder_\(UUID().uuidString).json")
    try Data(json.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    return try Config.load(from: url.path)
  }

  @Test func missingKeysTakeDefaults() throws {
    let config = try load("""
    { "release": { "name": "Mini", "bundleIdPrefix": "com.example" } }
    """)
    #expect(config.release.name == "Mini")
    #expect(config.release.version == nil)
    #expect(config.release.dependencyBundleIdPrefix == nil)
    #expect(config.release.archiveName == "{name}-{version}.zip")
    #expect(config.products == Config.Products())
    #expect(config.products.exclude.isEmpty && config.products.base == nil)
    #expect(config.frameworks.merge.isEmpty && config.frameworks.dynamic.isEmpty)
    #expect(config.build.platforms == [.ios, .catalyst, .macos, .tvos, .watchos])
    #expect(config.build.defineSwiftPackage)
    #expect(config.build.settings == BuildSettings())
    #expect(config.build.versionMacro == nil)
    #expect(config.build.linkage == .static)
    #expect(config.layout.privacyBundle.isEmpty && config.layout.infoPlist.isEmpty)
    #expect(config.zip.files.isEmpty && config.zip.externalArtifacts.isEmpty)
    #expect(config.verify.skipImports.isEmpty)
  }

  @Test func missingKeysInsideASectionTakeDefaults() throws {
    let config = try load("""
    {
      "release": { "name": "Mini", "bundleIdPrefix": "com.example" },
      "build": { "defineSwiftPackage": false },
      "zip": { "externalArtifacts": [{ "to": "Analytics", "url": "https://example.com/a.zip" }] }
    }
    """)
    #expect(!config.build.defineSwiftPackage)
    #expect(config.build.platforms == DefaultPlatforms.defaultValue)
    let artifact = try #require(config.zip.externalArtifacts.first)
    #expect(artifact.subpath == nil)
    #expect(!artifact.stripSignatures)
  }

  @Test func allowsJSON5Comments() throws {
    let config = try load("""
    {
      // A line comment.
      "release": {
        "name": "Mini", /* A block comment. */
        "bundleIdPrefix": "com.example",
      },
    }
    """)
    #expect(config.release.bundleIdPrefix == "com.example")
  }

  @Test(arguments: ["name", "bundleIdPrefix"])
  func requiresReleaseIdentity(key: String) throws {
    let release = ["name": "\"Mini\"", "bundleIdPrefix": "\"com.example\""]
      .filter { $0.key != key }.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
    let error = #expect(throws: ZipBuilderError.self) {
      try load("{ \"release\": { \(release) } }")
    }
    #expect(error?.description.contains("missing required key `release.\(key)`") == true)
  }

  @Test func reportsWrongTypesWithTheirKeyPath() throws {
    let error = #expect(throws: ZipBuilderError.self) {
      try load("""
      {
        "release": { "name": "Mini", "bundleIdPrefix": "com.example" },
        "build": { "platforms": ["ios", "android"] }
      }
      """)
    }
    #expect(error?.description.contains("build.platforms.1") == true)
  }

  @Test func decodesTheLinkage() throws {
    let release = #""release": { "name": "Mini", "bundleIdPrefix": "com.example" }"#
    for linkage in Linkage.allCases {
      let config = try load(#"{ \#(release), "build": { "linkage": "\#(linkage.rawValue)" } }"#)
      #expect(config.build.linkage == linkage)
    }
    #expect(Linkage.allCases.map(\.rawValue) == ["static", "dynamic"])
    let error = #expect(throws: ZipBuilderError.self) {
      try load(#"{ \#(release), "build": { "linkage": "shared" } }"#)
    }
    #expect(error?.description.contains("build.linkage") == true)
  }

  @Test func decodesTheStaticFrameworks() throws {
    let release = #""release": { "name": "Mini", "bundleIdPrefix": "com.example" }"#
    #expect(try load("{ \(release) }").frameworks.static.isEmpty)
    let config = try load(#"{ \#(release), "frameworks": { "static": ["A", "B"] } }"#)
    #expect(config.frameworks.static == ["A", "B"])
  }

  /// A directory holding the given config files, each a minimal config named after its file.
  private func directory(with names: [String]) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-config-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for name in names {
      try Data("""
      // \(name)
      { "release": { "name": "\(name)", "bundleIdPrefix": "com.example" } }
      """.utf8).write(to: directory.appendingPathComponent(name))
    }
    return directory
  }

  @Test func prefersJSONCAndAcceptsJSON() throws {
    let both = try directory(with: ["zip_builder.jsonc", "zip_builder.json"])
    defer { try? FileManager.default.removeItem(at: both) }
    let warnings = Warnings()
    let preferred = try Warnings.$collected.withValue(warnings) {
      try Config.loadDefault(in: both.path)
    }
    #expect(preferred?.release.name == "zip_builder.jsonc")
    #expect(warnings.all == [
      "\(both.path)/zip_builder.json is ignored: zip_builder.jsonc takes precedence.",
    ])

    let json = try directory(with: ["zip_builder.json"])
    defer { try? FileManager.default.removeItem(at: json) }
    #expect(Config.file(in: json.path) == json.appendingPathComponent("zip_builder.json").path)
    #expect(try Config.loadDefault(in: json.path)?.release.name == "zip_builder.json")

    let none = try directory(with: [])
    defer { try? FileManager.default.removeItem(at: none) }
    #expect(Config.file(in: none.path) == nil)
    #expect(try Config.loadDefault(in: none.path) == nil)
  }

  /// Where the config files would be, preferred first, whether or not they exist.
  @Test func configPathsArePreferredFirst() {
    #expect(Config.paths(in: "/repo") == ["/repo/zip_builder.jsonc", "/repo/zip_builder.json"])
  }

  @Test func sharedOptionsFindTheConfigFile() throws {
    let json = try directory(with: ["zip_builder.json"])
    defer { try? FileManager.default.removeItem(at: json) }
    let found = try #require(try ZipBuilderCommand.parseAsRoot([
      "plan", "--package-path", json.path,
    ]) as? PlanCommand)
    #expect(try found.options.loadConfig().release.name == "zip_builder.json")

    let none = try directory(with: [])
    defer { try? FileManager.default.removeItem(at: none) }
    let missing = try #require(try ZipBuilderCommand.parseAsRoot([
      "plan", "--package-path", none.path,
    ]) as? PlanCommand)
    let error = #expect(throws: ZipBuilderError.self) { try missing.options.loadConfig() }
    #expect(error?.description.contains("zip_builder.jsonc") == true)
  }

  @Test func reportsAMissingFile() {
    let error = #expect(throws: ZipBuilderError.self) {
      try Config.load(from: "/nonexistent/zip_builder.json")
    }
    #expect(error?.description.contains("/nonexistent/zip_builder.json") == true)
  }

  /// `--config` wins over the default, and must exist; a missing default is nil.
  @Test func explicitConfigTakesPrecedenceOverTheDefault() throws {
    let both = try directory(with: ["zip_builder.jsonc", "other.json"])
    defer { try? FileManager.default.removeItem(at: both) }
    let explicit = both.appendingPathComponent("other.json").path
    #expect(try Config.load(from: explicit, orDefaultIn: both.path)?.release.name == "other.json")
    #expect(try Config.load(from: nil, orDefaultIn: both.path)?.release.name
      == "zip_builder.jsonc")

    let none = try directory(with: [])
    defer { try? FileManager.default.removeItem(at: none) }
    #expect(try Config.load(from: nil, orDefaultIn: none.path) == nil)
    #expect(throws: ZipBuilderError.self) {
      try Config.load(from: none.appendingPathComponent("missing.json").path,
                      orDefaultIn: none.path)
    }
  }

  @Test func decodesPlatformKeysAndBuildSettings() throws {
    let config = try load("""
    {
      "release": { "name": "Mini", "bundleIdPrefix": "com.example" },
      "build": {
        "deploymentTargets": { "ios": "15.0", "catalyst": "15.0" },
        "settings": { "A": "YES", "B": ["x", "y"] }
      }
    }
    """)
    #expect(config.build.deploymentTargets == [.ios: "15.0", .catalyst: "15.0"])
    #expect(config.build.settings == ["A": "YES", "B": ["x", "y"]])
  }

  @Test func roundTrips() throws {
    let config = try load("""
    {
      "release": { "name": "Mini", "bundleIdPrefix": "com.example", "version": "1.0.0" },
      "products": { "base": { "product": "Mini", "frameworks": ["CoreC"] } },
      "frameworks": { "platforms": { "CoreC": ["ios"] } }
    }
    """)
    let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
    #expect(decoded == config)
  }

  /// The repo's real config translates every key of the old tool's config, and has no unknown
  /// keys, so a typo in it fails CI.
  @Test func decodesTheRepoConfig() async throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // Config
      .deletingLastPathComponent() // ZipBuilderTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // zip_builder
      .deletingLastPathComponent() // scripts
      .deletingLastPathComponent()
    let (config, warnings) = try await collectingWarnings {
      try Config.load(from: repoRoot.appendingPathComponent("zip_builder.jsonc").path)
    }

    #expect(warnings.isEmpty)
    #expect(config.release.name == "Firebase")
    #expect(config.release.version == nil)
    #expect(config.release.dependencyBundleIdPrefix == "org.cocoapods")
    #expect(config.release.archiveName == "{name}-{version}-latest.zip")
    #expect(config.products.exclude.contains("FirebaseAnalyticsCore"))
    #expect(config.products.add == [Config.Product(name: "FirebaseABTesting",
                                                   targets: ["FirebaseABTesting"])])
    #expect(config.products.base?.product == "FirebaseAnalytics")
    #expect(config.products.platforms["FirebaseInAppMessaging"] == [.ios, .catalyst])
    #expect(config.products.extraFrameworks["FirebasePerformance"]?
      .contains("FirebaseRemoteConfig") == true)
    #expect(config.frameworks.aggregate == ["GoogleUtilities"])
    #expect(config.frameworks.merge["FirebaseAuth"] == ["FirebaseAuthInternal"])
    // With source Firestore, its targets get the names of the prebuilt binaries.
    #expect(config.frameworks.rename == [
      "GTMSessionFetcherCore": "GTMSessionFetcher",
      "FirebaseFirestoreInternalWrapper": "FirebaseFirestoreInternal",
      "abseil": "absl", "gRPC-Core": "grpc", "gRPC-cpp": "grpcpp",
    ])
    #expect(config.frameworks.static.isEmpty)
    #expect(config.frameworks.publicHeaders["FirebaseStorage"] == ["FirebaseStorage/Typedefs"])
    #expect(config.frameworks.hiddenHeaders == ["IsAppEncrypted.h"])
    #expect(config.frameworks.platforms["leveldb"] == [.ios, .catalyst, .macos, .tvos])
    #expect(config.build.architectures["watchos"] == ["arm64", "arm64_32"])
    #expect(!config.build.defineSwiftPackage)
    #expect(config.build.swiftVersion["FirebaseAILogic"] == "6.0")
    // The project settings already allow non-modular includes.
    #expect(config.build.settings == BuildSettings())
    #expect(config.build.versionMacro == "Firebase_VERSION")
    #expect(config.layout.privacyBundle["GTMSessionFetcher"] == "GTMSessionFetcher_Core_Privacy")
    #expect(config.layout.infoPlist == ["MinimumOSVersion": "100.0"])
    #expect(config.zip.files.map(\.to) == [".", "FirebaseCrashlytics"])
    #expect(config.verify.skipImports == ["AppCheckCore", "absl", "grpc", "grpcpp",
                                          "openssl_grpc", "leveldb"])
  }
}
