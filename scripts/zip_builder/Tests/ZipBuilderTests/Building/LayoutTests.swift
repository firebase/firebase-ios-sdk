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

/// `applyLayout` on a synthetic `.xcframework` with an iOS (flat) and a macOS (versioned) slice.
struct LayoutTests {
  static func makeXCFramework() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/layout/\(UUID().uuidString)/N.xcframework")
    let manager = FileManager.default
    func write(_ path: String, _ text: String = "x") throws {
      let url = root.appendingPathComponent(path)
      try manager.createDirectory(at: url.deletingLastPathComponent(),
                                  withIntermediateDirectories: true)
      try Data(text.utf8).write(to: url)
    }
    func writePlist(_ path: String) throws {
      let info: [String: Any] = ["CFBundleExecutable": "N", "CFBundleName": "N",
                                 "CFBundlePackageType": "FMWK", "MinimumOSVersion": "15.0",
                                 "CFBundleIdentifier": "com.example.N"]
      try PropertyListSerialization.data(fromPropertyList: info, format: .binary, options: 0)
        .write(to: root.appendingPathComponent(path))
    }
    try write("Info.plist", "<plist/>")
    let ios = "ios-arm64/N.framework"
    for file in ["N", "Headers/N.h", "Modules/module.modulemap", "PrivacyInfo.xcprivacy",
                 "Story.storyboardc/Info.plist", "close.png"] {
      try write("\(ios)/\(file)")
    }
    try writePlist("\(ios)/Info.plist")
    let macos = "macos-arm64_x86_64/N.framework"
    for file in ["Versions/A/N", "Versions/A/Headers/N.h", "Versions/A/Resources/close.png",
                 "Versions/A/Resources/PrivacyInfo.xcprivacy"] {
      try write("\(macos)/\(file)")
    }
    try writePlist("\(macos)/Versions/A/Resources/Info.plist")
    let mac = root.appendingPathComponent(macos)
    try manager.createSymbolicLink(atPath: mac.appendingPathComponent("Versions/Current").path,
                                   withDestinationPath: "A")
    for link in ["N", "Headers", "Resources"] {
      try manager.createSymbolicLink(atPath: mac.appendingPathComponent(link).path,
                                     withDestinationPath: "Versions/Current/\(link)")
    }
    return root
  }

  static func plist(_ url: URL) throws -> [String: Any] {
    try #require(try PropertyListSerialization.propertyList(
      from: Data(contentsOf: url), format: nil
    ) as? [String: Any])
  }

  static func contents(_ url: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
  }

  @Test func flatSlice() throws {
    let xcframework = try Self.makeXCFramework()
    try applyLayout(Layout(privacyBundle: "N_Privacy", resourceBundle: "NResources",
                           infoPlist: ["MinimumOSVersion": "100.0"]),
                    to: xcframework.path, name: "N")
    let slice = xcframework.appendingPathComponent("ios-arm64/N.framework")
    #expect(try Self.contents(slice) ==
      ["Headers", "Info.plist", "Modules", "N", "NResources.bundle", "N_Privacy.bundle"])
    let privacy = slice.appendingPathComponent("N_Privacy.bundle")
    #expect(try Self.contents(privacy) == ["Info.plist", "PrivacyInfo.xcprivacy"])
    let resources = slice.appendingPathComponent("NResources.bundle")
    #expect(try Self.contents(resources) == ["Info.plist", "Story.storyboardc", "close.png"])

    let info = try Self.plist(slice.appendingPathComponent("Info.plist"))
    #expect(info["MinimumOSVersion"] as? String == "100.0")
    #expect(info["CFBundleExecutable"] as? String == "N")
    let bundleInfo = try Self.plist(privacy.appendingPathComponent("Info.plist"))
    #expect(bundleInfo["CFBundleName"] as? String == "N_Privacy")
    #expect(bundleInfo["CFBundlePackageType"] as? String == "BNDL")
    #expect(bundleInfo["CFBundleExecutable"] == nil)
    #expect(bundleInfo["MinimumOSVersion"] as? String == "15.0") // the framework's, unchanged
  }

  @Test func versionedSlice() throws {
    let xcframework = try Self.makeXCFramework()
    try applyLayout(Layout(privacyBundle: "N_Privacy", resourceBundle: "NResources",
                           infoPlist: ["MinimumOSVersion": "100.0"]),
                    to: xcframework.path, name: "N")
    let resources = xcframework
      .appendingPathComponent("macos-arm64_x86_64/N.framework/Versions/A/Resources")
    #expect(try Self.contents(resources) == ["Info.plist", "NResources.bundle", "N_Privacy.bundle"])
    let privacy = resources.appendingPathComponent("N_Privacy.bundle/Contents")
    #expect(try Self.contents(privacy) == ["Info.plist", "Resources"])
    #expect(try Self.contents(privacy.appendingPathComponent("Resources")) ==
      ["PrivacyInfo.xcprivacy"])
    #expect(try Self
      .contents(resources.appendingPathComponent("NResources.bundle/Contents/Resources"))
      == ["close.png"])
    let info = try Self.plist(resources.appendingPathComponent("Info.plist"))
    #expect(info["MinimumOSVersion"] as? String == "100.0")
  }

  @Test func emptyLayoutChangesNothing() throws {
    let xcframework = try Self.makeXCFramework()
    let slice = xcframework.appendingPathComponent("ios-arm64/N.framework")
    let before = try Self.contents(slice)
    let infoBefore = try Data(contentsOf: slice.appendingPathComponent("Info.plist"))
    try applyLayout(Layout(), to: xcframework.path, name: "N")
    #expect(try Self.contents(slice) == before)
    #expect(try Data(contentsOf: slice.appendingPathComponent("Info.plist")) == infoBefore)
  }

  @Test func noPrivacyManifestNoBundle() throws {
    let xcframework = try Self.makeXCFramework()
    let slice = xcframework.appendingPathComponent("ios-arm64/N.framework")
    try FileManager.default.removeItem(at: slice.appendingPathComponent("PrivacyInfo.xcprivacy"))
    try applyLayout(Layout(privacyBundle: "N_Privacy"), to: xcframework.path, name: "N")
    #expect(try !(Self.contents(slice)).contains("N_Privacy.bundle"))
  }

  @Test func aMissingInfoPlistNamesTheFileAndTheReason() throws {
    let xcframework = try Self.makeXCFramework()
    let info = xcframework.appendingPathComponent("ios-arm64/N.framework/Info.plist")
    try FileManager.default.removeItem(at: info)
    let error = #expect(throws: ZipBuilderError.self) {
      try applyLayout(Layout(), to: xcframework.path, name: "N")
    }
    let description = try #require(error).description
    #expect(description.hasPrefix("Couldn't read \(info.path): "))
    #expect(description.count > "Couldn't read \(info.path): ".count)
  }

  @Test func anInfoPlistThatIsntADictionaryFails() throws {
    let xcframework = try Self.makeXCFramework()
    let info = xcframework.appendingPathComponent("ios-arm64/N.framework/Info.plist")
    try PropertyListSerialization.data(fromPropertyList: ["N"], format: .binary, options: 0)
      .write(to: info)
    let error = #expect(throws: ZipBuilderError.self) {
      try applyLayout(Layout(), to: xcframework.path, name: "N")
    }
    #expect(error?.description == "\(info.path) isn't a dictionary.")
  }
}
