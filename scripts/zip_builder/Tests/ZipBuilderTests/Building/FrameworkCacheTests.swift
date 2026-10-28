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

/// A throwaway package on disk: `B` ← `A` → `Bin` (a binary), and an unrelated `C`.
struct SyntheticPackage {
  let root: URL

  init() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/synthetic/\(UUID().uuidString)")
    try write("A/a.m", "int a(void) { return 1; }\n")
    try write("A/include/A.h", "int a(void);\n")
    try write("A/Resources/data.json", "{}\n")
    try write("B/b.m", "int b(void) { return 2; }\n")
    try write("B/include/B.h", "int b(void);\n")
    try write("C/c.m", "int c(void) { return 3; }\n")
    try write("Bin.xcframework/Info.plist", "<plist/>\n")
    try write("Bin.xcframework/ios-arm64/Bin.framework/Bin", "binary\n")
  }

  func write(_ path: String, _ text: String) throws {
    let url = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
  }

  func append(_ path: String, _ text: String) throws {
    let url = root.appendingPathComponent(path)
    let handle = try FileHandle(forWritingTo: url)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(text.utf8))
    try handle.close()
  }

  static func framework(_ name: String, dependencies: [String] = [],
                        resources: [Resource] = []) -> Framework {
    Framework(
      name: name, moduleName: name, package: "Synthetic",
      sources: [Source(path: "\(name)/\(name.lowercased()).m")],
      headers: [Header(path: "\(name)/include/\(name).h", visibility: .public)],
      resources: resources, settings: ["PRODUCT_NAME": .string(name)],
      dependencies: dependencies.map { Dependency(name: $0) }, platforms: [.ios, .macos],
      bundleID: "com.example.\(name)", version: "1.0.0", isDynamic: false,
      layout: Layout(privacyBundle: "\(name)_Privacy")
    )
  }

  static let plan = Plan(
    settings: ["SKIP_INSTALL": "NO"],
    frameworks: [
      framework("B"),
      framework("A", dependencies: ["B", "Bin"],
                resources: [Resource(path: "A/Resources/data.json",
                                     rule: .process(localization: nil))]),
      Framework(name: "C", moduleName: "C", package: "Synthetic", sources: [Source(path: "C/c.m")],
                headers: [], resources: [], settings: [:], dependencies: [], platforms: [.ios],
                bundleID: "com.example.C", version: "1.0.0", isDynamic: false, layout: Layout()),
    ],
    binaries: [Binary(name: "Bin", path: "Bin.xcframework", platforms: [.ios], version: "2.0")],
    folders: []
  )

  func fingerprints(_ plan: Plan = plan, xcode: String = "Xcode 26.2") throws -> [String: String] {
    try ZipBuilder.fingerprints(of: plan, packageRoot: root.path, xcodeVersion: xcode)
  }
}

struct FingerprintTests {
  @Test func stable() throws {
    let package = try SyntheticPackage()
    let first = try package.fingerprints()
    #expect(try first == (package.fingerprints()))
    #expect(first.keys.sorted() == ["A", "B", "C"])
    #expect(first.values.allSatisfy { $0.count == 64 })
    #expect(Set(first.values).count == 3)
    // Fingerprinting a plan that holds only A's closure gives A the same fingerprint.
    var closure = SyntheticPackage.plan
    closure.frameworks.removeAll { $0.name == "C" }
    #expect(try package.fingerprints(closure)["A"] == first["A"])
  }

  @Test func sourceContentChangesOnlyThatFramework() throws {
    let package = try SyntheticPackage()
    let before = try package.fingerprints()
    try package.append("A/a.m", "// a comment\n")
    let after = try package.fingerprints()
    #expect(after["A"] != before["A"])
    #expect(after["B"] == before["B"])
    #expect(after["C"] == before["C"])
  }

  @Test func headerAndResourceContentsCount() throws {
    let package = try SyntheticPackage()
    let before = try package.fingerprints()
    try package.append("A/Resources/data.json", "\n")
    let afterResource = try package.fingerprints()
    #expect(afterResource["A"] != before["A"])
    try package.append("A/include/A.h", "// more\n")
    #expect(try package.fingerprints()["A"] != afterResource["A"])
  }

  @Test func dependencyChangePropagatesToDependents() throws {
    let package = try SyntheticPackage()
    let before = try package.fingerprints()
    try package.append("B/b.m", "// a comment\n")
    let after = try package.fingerprints()
    #expect(after["B"] != before["B"])
    #expect(after["A"] != before["A"])
    #expect(after["C"] == before["C"])
  }

  @Test func binaryContentChangesDependents() throws {
    let package = try SyntheticPackage()
    let before = try package.fingerprints()
    try package.write("Bin.xcframework/ios-arm64/Bin.framework/Bin", "new binary\n")
    let after = try package.fingerprints()
    #expect(after["A"] != before["A"])
    #expect(after["B"] == before["B"])
  }

  @Test func layoutDoesNotCount() throws {
    let package = try SyntheticPackage()
    var plan = SyntheticPackage.plan
    let before = try package.fingerprints(plan)
    plan.frameworks[1].layout = Layout(privacyBundle: "Other", resourceBundle: "Res",
                                       infoPlist: ["MinimumOSVersion": "100.0"])
    #expect(try package.fingerprints(plan) == before)
  }

  @Test func settingsPlatformsAndXcodeCount() throws {
    let package = try SyntheticPackage()
    let before = try package.fingerprints()
    var plan = SyntheticPackage.plan
    plan.settings["OTHER"] = "1"
    #expect(try package.fingerprints(plan)["C"] != before["C"])
    plan = SyntheticPackage.plan
    plan.frameworks[2].platforms = [.ios, .tvos]
    #expect(try package.fingerprints(plan)["C"] != before["C"])
    #expect(try package.fingerprints(xcode: "Xcode 27.0")["C"] != before["C"])
  }

  @Test func pathsAreRelativeToThePackageRoot() throws {
    let package = try SyntheticPackage()
    let moved = package.root.deletingLastPathComponent()
      .appendingPathComponent("moved-\(UUID().uuidString)")
    try FileManager.default.copyItem(at: package.root, to: moved)
    let elsewhere = try fingerprints(of: SyntheticPackage.plan, packageRoot: moved.path,
                                     xcodeVersion: "Xcode 26.2")
    #expect(try elsewhere == (package.fingerprints()))
  }

  @Test func missingFileIsAnError() throws {
    let package = try SyntheticPackage()
    try FileManager.default.removeItem(at: package.root.appendingPathComponent("C/c.m"))
    #expect(throws: ZipBuilderError.self) { try package.fingerprints() }
  }

  /// A searches the package root (outside its own directory, `A`), like Firebase's repo-root
  /// header search paths.
  @Test func headersUnderOutsideSearchPathsCount() throws {
    let package = try SyntheticPackage()
    var plan = SyntheticPackage.plan
    plan.frameworks[1].settings["HEADER_SEARCH_PATHS"] = ["$(inherited)", ".", "A"]
    try package.write("Shared/shared.h", "#define SHARED 1\n")
    try package.write("Shared/notes.m", "// not a header\n")
    let work = package.root.appendingPathComponent("work").path
    func fingerprints() throws -> [String: String] {
      try ZipBuilder.fingerprints(of: plan, packageRoot: package.root.path,
                                  xcodeVersion: "Xcode 26.2", excluding: [work])
    }
    let before = try fingerprints()

    try package.append("Shared/notes.m", "// still not a header\n")
    try package.write(".hidden/hidden.h", "\n")
    try package.write("work/Generated/A/A.h", "\n")
    #expect(try fingerprints() == before)

    try package.append("Shared/shared.h", "// changed\n")
    let after = try fingerprints()
    #expect(after["A"] != before["A"])
    #expect(after["B"] == before["B"]) // no search path outside its own directory
    #expect(after["C"] == before["C"])
  }

  /// Build outputs under a search path (another work dir, the cache, DerivedData, bundles) hold
  /// copies of headers, not sources, so they don't count.
  @Test func buildOutputsUnderSearchPathsDontCount() throws {
    let package = try SyntheticPackage()
    var plan = SyntheticPackage.plan
    plan.frameworks[1].settings["HEADER_SEARCH_PATHS"] = ["."]
    let cache = package.root.appendingPathComponent("my-cache").path
    func fingerprints() throws -> [String: String] {
      try ZipBuilder.fingerprints(of: plan, packageRoot: package.root.path,
                                  xcodeVersion: "Xcode 26.2", excluding: [cache])
    }
    let before = try fingerprints()
    for path in ["my-cache/abc/A.h", "Out/DerivedData/x/A.h",
                 "Built/A.xcframework/ios-arm64/A.framework/Headers/A.h", "B/A.framework/A.h",
                 "P/A.xcodeproj/A.h", "P/A.xcarchive/A.h", "P/A.bundle/A.h",
                 "P/A.xcworkspace/A.h", "otherwork/xcframeworks/A.h"] {
      try package.write(path, "// a copy\n")
    }
    try package.write("otherwork/plan.json", "{}\n")
    #expect(try fingerprints() == before)
    try package.write("Notes/extra.inc", "// included\n") // includable files still count
    #expect(try fingerprints()["A"] != before["A"])
  }

  @Test func formatIsBumpedForTheSearchPathChanges() {
    #expect(fingerprintFormat == "zip-builder-2")
  }

  /// Exact fingerprints of fixed files, so any change to the fingerprint text shows up. A change
  /// here invalidates every cache entry, CI's included: make it only on purpose, and bump
  /// `fingerprintFormat` with it.
  @Test func goldenFingerprints() throws {
    let package = try SyntheticPackage()
    try package.write("Shared/shared.h", "#define SHARED 1\n")
    try package.write("C/module.modulemap", "module C { header \"c.h\" }\n")
    var plan = SyntheticPackage.plan
    // A has a framework dependency (B), a binary one (Bin), a resource, and search paths outside
    // its own directory: the package root and `Shared` from its settings, `B/include` from the
    // project's (outside A and C, inside B). C has a custom module map.
    plan.settings["USER_HEADER_SEARCH_PATHS"] = ["B/include"]
    plan.frameworks[1].settings["HEADER_SEARCH_PATHS"] = ["$(inherited)", ".", "Shared",
                                                          "A/include"]
    plan.frameworks[2].moduleMap = "C/module.modulemap"
    let fingerprints = try package.fingerprints(plan, xcode: "Xcode 26.2\nBuild version 17C52")
    #expect(fingerprints == [
      "A": "d3355e6cc0d6f6224dc3239dae8e53c6727ed0821e55a639b43833ae785e0b1c",
      "B": "6036dfcd8651a9349f384f081ee81e4529ce2f438753138d96cfb0f8ede2ead6",
      "C": "d29b417a8150af04e232e0bfadcc87fae1268d101131cffe22061845cd53dd8b",
    ])
  }
}

struct FrameworkCacheTests {
  static func makeCache() -> FrameworkCache {
    FrameworkCache(directory: FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-tests/cache/\(UUID().uuidString)").path)
  }

  @Test func storeAndHas() throws {
    let package = try SyntheticPackage()
    let cache = Self.makeCache()
    let xcframework = package.root.appendingPathComponent("Bin.xcframework").path
    #expect(!cache.has("abc", name: "Bin"))
    try cache.store(xcframework, for: "abc")
    #expect(cache.has("abc", name: "Bin"))
    #expect(cache.path(for: "abc", name: "Bin") == cache.directory + "/abc/Bin.xcframework")
    #expect(FileManager.default.fileExists(
      atPath: cache.path(for: "abc", name: "Bin") + "/ios-arm64/Bin.framework/Bin"
    ))
    #expect(!cache.has("abc", name: "Other"))
    // Nothing is left behind but the entry.
    #expect(try FileManager.default.contentsOfDirectory(atPath: cache.directory) == ["abc"])
  }

  @Test func storeKeepsTheExistingEntry() throws {
    let package = try SyntheticPackage()
    let cache = Self.makeCache()
    let xcframework = package.root.appendingPathComponent("Bin.xcframework").path
    try cache.store(xcframework, for: "abc")
    try package.write("Bin.xcframework/ios-arm64/Bin.framework/Bin", "v2\n")
    try cache.store(xcframework, for: "abc") // first writer wins
    let stored = try String(
      contentsOfFile: cache.path(for: "abc", name: "Bin") + "/ios-arm64/Bin.framework/Bin",
      encoding: .utf8
    )
    #expect(stored == "binary\n")
    #expect(try FileManager.default.contentsOfDirectory(atPath: cache.directory) == ["abc"])
  }

  /// Another build stores the same fingerprint between this store's copy and its move.
  @Test func anEntryThatAppearsMeanwhileIsKept() throws {
    let package = try SyntheticPackage()
    let cache = Self.makeCache()
    let other = URL(fileURLWithPath: cache.path(for: "abc", name: "Bin"))
    try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
    try Data("theirs\n".utf8).write(to: other.appendingPathComponent("marker"))
    try cache.store(package.root.appendingPathComponent("Bin.xcframework").path, for: "abc")
    #expect(try FileManager.default.contentsOfDirectory(atPath: other.path) == ["marker"])
    #expect(try FileManager.default.contentsOfDirectory(atPath: cache.directory) == ["abc"])
  }

  @Test func anEmptyEntryDirectoryIsKeptToo() throws {
    let package = try SyntheticPackage()
    let cache = Self.makeCache()
    let entry = cache.directory + "/abc"
    try FileManager.default.createDirectory(atPath: entry, withIntermediateDirectories: true)
    try cache.store(package.root.appendingPathComponent("Bin.xcframework").path, for: "abc")
    #expect(try FileManager.default.contentsOfDirectory(atPath: entry).isEmpty)
  }

  @Test func anInterruptedStoreIsNotCached() throws {
    let cache = Self.makeCache()
    // What an interrupted `store` leaves: a temporary directory, never the entry itself.
    let partial = URL(fileURLWithPath: cache.directory)
      .appendingPathComponent(".tmp-1234/Bin.xcframework")
    try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
    #expect(!cache.has("1234", name: "Bin"))
    #expect(throws: (any Error).self) { try cache.store("/nonexistent/Bin.xcframework", for: "x") }
    #expect(!cache.has("x", name: "Bin"))
    #expect(!FileManager.default.fileExists(atPath: cache.directory + "/x"))
  }

  @Test func defaultDirectory() {
    #expect(FrameworkCache.defaultDirectory.hasSuffix("/Library/Caches/zip-builder/frameworks"))
  }
}
