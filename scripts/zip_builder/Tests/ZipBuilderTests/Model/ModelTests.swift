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

struct ModelTests {
  @Test func planRoundTrips() throws {
    let framework = Framework(
      name: "CoreC", moduleName: "CoreC", package: "Mini",
      sources: [
        Source(path: "Sources/CoreC/a.m"),
        Source(path: "Sources/X/b.m", platforms: [.ios]),
      ],
      headers: [Header(path: "Sources/CoreC/include/CoreC.h", visibility: .public),
                Header(path: "Sources/CoreC/Private.h", visibility: .private)],
      resources: [Resource(path: "Sources/CoreC/en.lproj/a.strings",
                           rule: .process(localization: "en")),
                  Resource(path: "Sources/CoreC/data.json", rule: .copy)],
      settings: ["GCC_PREPROCESSOR_DEFINITIONS[sdk=iphoneos*]": ["A=1"]],
      dependencies: [Dependency(name: "Prebuilt", platforms: [.ios]), Dependency(name: "Other")],
      platforms: [.ios, .macos],
      bundleID: "com.example.CoreC", version: "1.0.0", isDynamic: false,
      layout: Layout(privacyBundle: "CoreC_Privacy", infoPlist: ["MinimumOSVersion": "100.0"])
    )
    let plan = Plan(
      settings: ["IPHONEOS_DEPLOYMENT_TARGET": "15.0"],
      frameworks: [framework],
      binaries: [Binary(name: "Prebuilt", path: "Prebuilt.xcframework", platforms: [.ios],
                        version: "1.0.0")],
      folders: [Folder(name: "Mini", frameworks: ["CoreC", "Prebuilt"], files: [])]
    )
    let decoded = try JSONDecoder().decode(Plan.self, from: JSONEncoder().encode(plan))
    #expect(decoded == plan)
  }

  /// `Plan.read(from:)` reads back what `json()` writes.
  @Test func planReadsItsJSON() throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-plan-\(UUID().uuidString).json")
    try SyntheticPackage.plan.json().write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    #expect(try Plan.read(from: file.path) == SyntheticPackage.plan)
    #expect(throws: (any Error).self) { try Plan.read(from: "/nonexistent/plan.json") }
  }

  /// Platforms in declaration order, each followed by its simulator.
  @Test func frameworkDestinations() {
    var framework = SyntheticPackage.framework("A")
    framework.platforms = [.tvos, .ios, .catalyst]
    #expect(framework.destinations.map(\.name) ==
      ["ios", "ios-simulator", "catalyst", "tvos", "tvos-simulator"])
    framework.platforms = []
    #expect(framework.destinations.isEmpty)
  }

  /// `destinations` is computed, so it isn't encoded (and doesn't change fingerprints).
  @Test func destinationsArentEncoded() throws {
    let json = try String(decoding: JSONEncoder().encode(SyntheticPackage.framework("A")),
                          as: UTF8.self)
    #expect(!json.contains("destinations"))
  }

  @Test func nameLookups() {
    let plan = SyntheticPackage.plan // frameworks B, A, C; binary Bin
    #expect(plan.frameworkNames == ["A", "B", "C"])
    #expect(plan.hasFrameworkOrBinary(named: "A"))
    #expect(plan.hasFrameworkOrBinary(named: "Bin"))
    #expect(!plan.hasFrameworkOrBinary(named: "Missing"))
  }

  /// Bundle ID components only hold letters, digits and hyphens, as with CocoaPods.
  @Test func bundleIDComponents() {
    #expect(bundleIDComponent("openssl_grpc") == "openssl-grpc")
    #expect(bundleIDComponent("gRPC-Core") == "gRPC-Core")
    #expect(bundleIDComponent("a.b c") == "a-b-c")
  }

  /// A rename replaces the bundle ID's last component, spelled as a bundle ID component.
  @Test func renamingUpdatesTheBundleID() {
    var framework = SyntheticPackage.framework("A")
    framework.name = "my_lib"
    framework.bundleID = "com.example.my-lib"
    framework.rename(to: "new_lib")
    #expect(framework.bundleID == "com.example.new-lib")
    #expect(framework.settings["PRODUCT_BUNDLE_IDENTIFIER"] == "com.example.new-lib")
  }
}
