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

/// `Config.load(from:)` warns about keys that aren't config keys, since the decoder ignores them.
struct UnknownKeysTests {
  /// The warnings from loading a config with `sections` after the required `release` group.
  private func warnings(loading sections: String) async throws -> [String] {
    try await warnings(loadingJSON: #"{ "release": { "name": "Mini", "bundleIdPrefix": "c" }, "#
      + "\(sections) }")
  }

  /// The warnings from loading the config `json`.
  private func warnings(loadingJSON json: String) async throws -> [String] {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip_builder_\(UUID().uuidString).jsonc")
    try Data(json.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    return try await collectingWarnings { try Config.load(from: url.path) }.warnings
  }

  @Test func warnsAboutAnUnknownTopLevelKey() async throws {
    #expect(try await warnings(loading: #""framework": {}"#)
      == ["framework isn't a config key; ignored."])
  }

  @Test func warnsAboutAnUnknownKeyInAGroup() async throws {
    let warnings = try await warnings(loading: """
    "frameworks": { "privateHeader": ["*.h"], "dynamic": ["A"] },
    "release2": 1
    """)
    #expect(warnings == [
      "frameworks: privateHeader isn't a config key; ignored.",
      "release2 isn't a config key; ignored.",
    ])
  }

  @Test func warnsAboutUnknownKeysInsideArrayElementsAndOptionalStructs() async throws {
    let warnings = try await warnings(loading: """
    "products": {
      "add": [{ "name": "A", "targets": ["A"], "target": "A" }],
      "base": { "product": "A", "frameworks": [], "framework": [] }
    },
    "zip": {
      "files": [{ "to": ".", "files": [] }, { "to": ".", "files": [], "from": "x" }],
      "externalArtifacts": [{ "to": ".", "url": "https://example.com/a.zip", "strip": true }]
    }
    """)
    #expect(warnings == [
      "products.add[0]: target isn't a config key; ignored.",
      "products.base: framework isn't a config key; ignored.",
      "zip.externalArtifacts[0]: strip isn't a config key; ignored.",
      "zip.files[1]: from isn't a config key; ignored.",
    ])
  }

  /// Map keys are names, not config keys, and `build.settings` is a free-form map.
  @Test func doesNotCheckTheKeysOfMaps() async throws {
    let warnings = try await warnings(loading: """
    "products": { "rename": { "Anything": "Else" }, "platforms": { "Folder": ["ios"] } },
    "frameworks": { "merge": { "A": ["B"] } },
    "build": {
      "swiftVersion": { "*": "5" },
      "deploymentTargets": { "ios": "15.0" },
      "settings": { "ANY_SETTING": "YES", "OTHER[sdk=iphoneos*]": ["a"] }
    },
    "layout": { "infoPlist": { "MinimumOSVersion": "100.0" } }
    """)
    #expect(warnings.isEmpty)
  }

  /// Every key of every group, so a key added to `Config` is never reported as unknown.
  @Test func knowsEveryKey() async throws {
    let warnings = try await warnings(loadingJSON: """
    {
    "release": { "name": "Mini", "version": "1", "bundleIdPrefix": "c",
                 "dependencyBundleIdPrefix": "d", "archiveName": "a.zip" },
    "products": { "exclude": [], "add": [], "rename": {}, "withoutFolder": [],
                  "base": { "product": "A", "frameworks": [] }, "platforms": {},
                  "extraFrameworks": {}, "withoutDependencies": true },
    "frameworks": { "aggregate": [], "merge": {}, "rename": {}, "publicHeaders": {},
                    "privateHeaders": [], "hiddenHeaders": [], "platforms": {}, "dynamic": [],
                    "static": [] },
    "build": { "platforms": ["ios"], "deploymentTargets": {}, "architectures": {},
               "defineSwiftPackage": true, "defines": [], "swiftConditions": [],
               "swiftVersion": {}, "settings": {}, "versionMacro": "V" },
    "layout": { "privacyBundle": {}, "resourceBundles": {}, "infoPlist": {} },
    "zip": { "files": [], "externalArtifacts": [{ "to": ".", "url": "u", "subpath": "p",
                                                  "stripSignatures": true }] },
    "verify": { "skipImports": [] }
    }
    """)
    #expect(warnings.isEmpty)
  }
}
