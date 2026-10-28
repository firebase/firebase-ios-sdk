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

/// Slices that `FakeDistribution` can't make: library slices and versioned frameworks.
struct ReadSliceTests {
  /// A library slice keeps its headers in `HeadersPath` and its module map beside the library,
  /// which is its own binary. A macOS framework's binary is at `BinaryPath`, and its Info.plist
  /// is in `Resources/`.
  @Test func readsLibrarySlicesAndVersionedFrameworks() async throws {
    let fake = try FakeDistribution()
    try writePlist(["AvailableLibraries": [[
      "LibraryIdentifier": "ios-arm64", "LibraryPath": "libLib.a", "HeadersPath": "Include",
      "SupportedPlatform": "ios", "SupportedArchitectures": ["arm64"],
    ]]], to: "L/Lib.xcframework/Info.plist", in: fake)
    try fake.addFile("L/Lib.xcframework/ios-arm64/libLib.a", "!<arch>\n")
    try fake.addFile("L/Lib.xcframework/ios-arm64/Include/Lib.h")
    try fake.addFile("L/Lib.xcframework/ios-arm64/Modules/module.modulemap", "module Lib {}")

    let mac = "M/Mac.xcframework/macos-arm64/Mac.framework"
    try writePlist(["AvailableLibraries": [[
      "LibraryIdentifier": "macos-arm64", "LibraryPath": "Mac.framework",
      "BinaryPath": "Mac.framework/Versions/A/Mac", "SupportedPlatform": "macos",
      "SupportedArchitectures": ["arm64"],
    ]]], to: "M/Mac.xcframework/Info.plist", in: fake)
    try fake.addFile(mac + "/Versions/A/Mac", "!<arch>\n")
    try writePlist(["CFBundleShortVersionString": "3.0", "BuildNumber": 7],
                   to: mac + "/Resources/Info.plist", in: fake)

    let distribution = try await fake.read()
    let library = try #require(distribution.xcframeworks.first?.slices.first)
    #expect(!library.isFramework)
    #expect(library.binaryPath == fake.root + "/L/Lib.xcframework/ios-arm64/libLib.a")
    #expect(library.binaryKind == "static")
    #expect(library.headers == ["Lib.h"])
    #expect(library.modules == ["module.modulemap"])
    #expect(library.moduleMap == "module Lib {}")
    #expect(library.infoPlist.isEmpty)
    #expect(library.resourceBundles.isEmpty)

    let framework = try #require(distribution.xcframeworks.last?.slices.first)
    #expect(framework.binaryPath == fake.root + "/" + mac + "/Versions/A/Mac")
    #expect(framework.binaryKind == "static")
    #expect(framework.infoPlist == ["CFBundleShortVersionString": "3.0", "BuildNumber": "7"])
  }

  private func writePlist(_ plist: [String: Any], to path: String,
                          in fake: FakeDistribution) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml,
                                                  options: 0)
    try fake.addFile(path)
    try data.write(to: URL(fileURLWithPath: fake.root + "/" + path))
  }
}
