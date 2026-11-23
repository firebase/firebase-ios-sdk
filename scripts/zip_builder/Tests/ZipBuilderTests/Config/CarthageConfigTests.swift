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

/// The repository root, for tests that read its release data.
let repoRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent() // Config
  .deletingLastPathComponent() // ZipBuilderTests
  .deletingLastPathComponent() // Tests
  .deletingLastPathComponent() // zip_builder
  .deletingLastPathComponent() // scripts
  .deletingLastPathComponent()

/// The `carthage` group.
struct CarthageConfigTests {
  /// The config with `sections` after the required `release` group, loaded from a file, and the
  /// warnings loading it gave.
  private func load(_ sections: String) async throws -> (result: Config, warnings: [String]) {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip_builder_\(UUID().uuidString).jsonc")
    try Data(#"{ "release": { "name": "Mini", "bundleIdPrefix": "c" }, \#(sections) }"#.utf8)
      .write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    return try await collectingWarnings { try Config.load(from: url.path) }
  }

  @Test func decodesEveryKey() async throws {
    let (config, warnings) = try await load("""
    "carthage": {
      "url": "https://example.com/{version}/{archive}",
      "manifests": "Carthage/{folder}Binary.json",
      "defines": ["MINI_CARTHAGE=1"],
      "rebuild": "MiniCore",
      "files": { "Mini/CoreC.xcframework": ["NOTICES"] },
      "umbrellaFramework": {
        "folder": "Mini", "name": "MiniUmbrella", "header": "Mini.h", "binary": "dummy",
        "bundleIdentifier": "com.example.MiniUmbrella"
      }
    }
    """)
    #expect(warnings.isEmpty)
    let carthage = try #require(config.carthage)
    #expect(carthage.url == "https://example.com/{version}/{archive}")
    #expect(carthage.manifests == "Carthage/{folder}Binary.json")
    #expect(carthage.defines == ["MINI_CARTHAGE=1"])
    #expect(carthage.rebuild == "MiniCore")
    #expect(carthage.files == ["Mini/CoreC.xcframework": ["NOTICES"]])
    #expect(carthage.umbrellaFramework == Config.UmbrellaFramework(
      folder: "Mini", name: "MiniUmbrella", header: "Mini.h", binary: "dummy",
      bundleIdentifier: "com.example.MiniUmbrella"
    ))
  }

  @Test func onlyTheURLAndManifestsAreRequired() async throws {
    let (config, _) = try await load(#""carthage": { "url": "u", "manifests": "m" }"#)
    let carthage = try #require(config.carthage)
    #expect(carthage.defines == nil)
    #expect(carthage.rebuild == nil)
    #expect(carthage.files.isEmpty)
    #expect(carthage.umbrellaFramework == nil)

    let error = await #expect(throws: ZipBuilderError.self) {
      _ = try await load(#""carthage": { "manifests": "m" }"#)
    }
    #expect(error?.description.contains("missing required key `carthage.url`") == true)
  }

  @Test func isNilWithoutTheGroup() async throws {
    #expect(try await load(#""verify": {}"#).result.carthage == nil)
  }

  /// Like the other groups; `files` is keyed by paths, which aren't config keys.
  @Test func warnsAboutUnknownKeys() async throws {
    let (_, warnings) = try await load("""
    "carthage": {
      "url": "u", "manifests": "m", "manifest": "m",
      "files": { "Any/Path.xcframework": ["NOTICES"] },
      "umbrellaFramework": {
        "folder": "F", "name": "N", "header": "h", "binary": "b", "bundleIdentifier": "i",
        "bundleId": "i"
      }
    }
    """)
    #expect(warnings == [
      "carthage: manifest isn't a config key; ignored.",
      "carthage.umbrellaFramework: bundleId isn't a config key; ignored.",
    ])
  }

  /// Firebase's values, and the repo files they name.
  @Test func decodesTheRepoConfig() throws {
    let config = try Config.load(from: repoRoot.appendingPathComponent("zip_builder.jsonc").path)
    let carthage = try #require(config.carthage)
    #expect(carthage.url == "https://dl.google.com/dl/firebase/ios/carthage/{version}/{archive}")
    #expect(carthage.defines == ["FIREBASE_BUILD_CARTHAGE=1"])
    #expect(carthage.rebuild == "FirebaseCore")
    #expect(carthage.files == ["FirebaseAnalytics/FirebaseCore.xcframework": ["NOTICES"]])
    // The notices it copies are the ones the zip generates.
    #expect(config.zip.notices?.file == "NOTICES")
    let umbrella = try #require(carthage.umbrellaFramework)
    #expect(umbrella.folder == config.products.base?.product)
    let manifest = carthage.manifests.replacingOccurrences(of: "{folder}", with: umbrella.folder)
    for path in [manifest, umbrella.header, umbrella.binary] {
      #expect(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent(path).path),
              "\(path)")
    }
  }
}
