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

/// The files `makeProject` generates: combined privacy manifests, header collisions, embedded
/// resources. Inputs are written to a temporary package root.
struct GeneratedFilesTests {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-tests/files/\(UUID().uuidString)")

  private func file(_ path: String, _ contents: String) throws -> Path {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: url)
    return path
  }

  private func plist(_ value: [String: Any]) throws -> String {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml,
                                                  options: 0)
    return String(decoding: data, as: UTF8.self)
  }

  private func framework(headers: [Header] = [], resources: [Resource] = []) -> Framework {
    Framework(name: "Lib", moduleName: "Lib", package: "Pkg", sources: [], headers: headers,
              resources: resources, settings: [:], dependencies: [], platforms: [.ios],
              bundleID: "com.example.Lib", version: "1.0.0", isDynamic: false, layout: Layout())
  }

  @Test func combiningPrivacyManifests() {
    let first: [String: Any] = [
      "NSPrivacyTracking": false,
      "NSPrivacyTrackingDomains": ["a.example"],
      "NSPrivacyCollectedDataTypes": [["NSPrivacyCollectedDataType": "Crash"]],
      "NSPrivacyAccessedAPITypes": [[
        "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
        "NSPrivacyAccessedAPITypeReasons": ["C56D.1"],
      ]],
    ]
    let second: [String: Any] = [
      "NSPrivacyTracking": true,
      "NSPrivacyTrackingDomains": ["a.example", "b.example"],
      "NSPrivacyCollectedDataTypes": [["NSPrivacyCollectedDataType": "Crash"],
                                      ["NSPrivacyCollectedDataType": "Other"]],
      "NSPrivacyAccessedAPITypes": [
        ["NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
         "NSPrivacyAccessedAPITypeReasons": ["C56D.1", "1C8F.1"]],
        ["NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
         "NSPrivacyAccessedAPITypeReasons": ["C617.1"]],
      ],
    ]
    let combined = combinedPrivacyManifest([first, second]) as NSDictionary
    #expect(combined == [
      "NSPrivacyTracking": true,
      "NSPrivacyTrackingDomains": ["a.example", "b.example"],
      "NSPrivacyCollectedDataTypes": [["NSPrivacyCollectedDataType": "Crash"],
                                      ["NSPrivacyCollectedDataType": "Other"]],
      "NSPrivacyAccessedAPITypes": [
        ["NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
         "NSPrivacyAccessedAPITypeReasons": ["C56D.1", "1C8F.1"]],
        ["NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
         "NSPrivacyAccessedAPITypeReasons": ["C617.1"]],
      ],
    ] as NSDictionary)
  }

  @Test func severalPrivacyManifestsBecomeOneFile() throws {
    let a = try file("A/PrivacyInfo.xcprivacy", plist(["NSPrivacyTracking": false]))
    let b = try file("B/PrivacyInfo.xcprivacy", plist(["NSPrivacyTracking": true]))
    let other = Resource(path: "A/data.json", rule: .copy)
    let output = root.appendingPathComponent("Generated/Lib")
    let result = try addingGeneratedFiles(
      to: framework(resources: [Resource(path: a, rule: .process(localization: nil)), other,
                                Resource(path: b, rule: .process(localization: nil))]),
      packageRoot: root.path, directory: output.path
    )
    let combined = output.appendingPathComponent("PrivacyInfo.xcprivacy")
    #expect(result.resources == [other, Resource(path: combined.path,
                                                 rule: .process(localization: nil))])
    let written = try PropertyListSerialization.propertyList(from: Data(contentsOf: combined),
                                                             format: nil) as? NSDictionary
    #expect(written?["NSPrivacyTracking"] as? Bool == true)
  }

  @Test func aForwarderGivesWayToTheRealHeader() throws {
    // nanopb: spm_headers/pb.h only includes spm_headers/nanopb/pb.h.
    let forwarder = try file("spm_headers/pb.h", "// License\n#include \"nanopb/pb.h\"\n")
    let real = try file("spm_headers/nanopb/pb.h", "#pragma once\ntypedef int pb_size_t;\n")
    let other = try file("spm_headers/other.h", "int other(void);\n")
    let headers = resolvingHeaderCollisions(framework(headers: [
      Header(path: forwarder, visibility: .public), Header(path: real, visibility: .public),
      Header(path: other, visibility: .public),
    ]), packageRoot: root.path)
    #expect(headers.map(\.visibility) == [.project, .public, .public])
  }

  @Test func embeddedResourcesBecomeASource() throws {
    let data = try file("Res/hello.txt", "hi")
    var lib = framework(resources: [Resource(path: data, rule: .embedInCode)])
    lib.sources = [Source(path: "Lib.swift")]
    let output = root.appendingPathComponent("Generated/Lib")
    let result = try addingGeneratedFiles(to: lib, packageRoot: root.path, directory: output.path)
    let source = output.appendingPathComponent("embedded_resources.swift")
    #expect(result.resources.isEmpty)
    #expect(result.sources.map(\.path) == ["Lib.swift", source.path])
    #expect(try String(contentsOf: source, encoding: .utf8)
      .contains("static let hello_txt: [UInt8] = [104,105]"))
  }

  @Test func publicHeadersGetAGeneratedUmbrella() throws {
    let header = try file("include/Thing.h", "int thing(void);\n")
    let output = root.appendingPathComponent("Generated/Lib")
    let result = try addingGeneratedFiles(
      to: framework(headers: [Header(path: header, visibility: .public)]),
      packageRoot: root.path, directory: output.path
    )
    #expect(result.headers.last == Header(path: output.appendingPathComponent("Lib.h").path,
                                          visibility: .public))
    #expect(result.settings["MODULEMAP_FILE"] == nil)
    // Without public headers (pure Swift), the umbrella only declares the version symbols.
    let swiftOnly = try addingGeneratedFiles(to: framework(), packageRoot: root.path,
                                             directory: output.path)
    #expect(swiftOnly.headers == [Header(path: output.appendingPathComponent("Lib.h").path,
                                         visibility: .public)])
    let text = try String(contentsOf: output.appendingPathComponent("Lib.h"), encoding: .utf8)
    #expect(!text.contains("#import <Lib/"))
    #expect(text.contains("FOUNDATION_EXPORT double LibVersionNumber;"))
    // CocoaPods-style guarded UIKit import, so `import Lib` re-exports UIKit.
    #expect(text.contains("""
    #ifdef __OBJC__
    #import <Foundation/Foundation.h>
    #if __has_include(<UIKit/UIKit.h>)
    #import <UIKit/UIKit.h>
    #endif
    #else
    """))
    #expect(swiftOnly.settings["VERSIONING_SYSTEM"] == nil) // set project-wide
  }

  @Test func customModuleMapReplacesTheUmbrella() async throws {
    let plan = try await MiniPackage
      .plan(#""products": { "add": [{ "name": "C", "targets": ["CustomMap"] }] }"#)
    let customMap = try plan.framework("CustomMap")
    let output = root.appendingPathComponent("Generated/CustomMap")
    let result = try addingGeneratedFiles(to: customMap, packageRoot: MiniPackage.path,
                                          directory: output.path)
    #expect(result.headers == customMap.headers) // nothing generated
    let moduleMap = output.appendingPathComponent("module.modulemap")
    #expect(result.settings["MODULEMAP_FILE"] == .string(moduleMap.path))
    #expect(try String(contentsOf: moduleMap, encoding: .utf8) == """
    framework module CustomMap {
      umbrella header "CustomMap.h"
      header "CMExtra.h"
      exclude header "CMPrivate.h"
      export *
    }

    """)
  }
}
