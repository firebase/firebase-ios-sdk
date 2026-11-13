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

/// A slice of a synthetic `.xcframework`.
struct FakeSlice {
  var identifier: String
  var platform = "ios"
  var variant: String?
  var architectures = ["arm64"]
  var headers = ["Core.h"]
  var privateHeaders: [String] = []
  var moduleMap: String? = "framework module Core {\n  umbrella header \"Core.h\"\n}"
  var version = "1.0.0"
  var minimumOS = "100.0"
  var bundles: [String] = []
  var hasBinary = true
  var createsDirectory = true

  static let device = FakeSlice(identifier: "ios-arm64")
  static let simulator = FakeSlice(identifier: "ios-arm64_x86_64-simulator", variant: "simulator",
                                   architectures: ["arm64", "x86_64"])
}

/// A synthetic distribution in a temporary directory: just directories and plists, with "!<arch>"
/// files standing in for static binaries.
final class FakeDistribution {
  let root: Path

  init() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-test-\(UUID().uuidString)/Firebase").path
    try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(atPath: (root as NSString).deletingLastPathComponent)
  }

  func addFile(_ path: String, _ contents: String = "") throws {
    let full = root + "/" + path
    try FileManager.default.createDirectory(atPath: (full as NSString).deletingLastPathComponent,
                                            withIntermediateDirectories: true)
    try contents.write(toFile: full, atomically: true, encoding: .utf8)
  }

  @discardableResult
  func addXCFramework(_ name: String, in folder: String,
                      slices: [FakeSlice] = [.device, .simulator]) throws -> Path {
    let xcframework = "\(folder)/\(name).xcframework"
    let libraries = slices.map { slice -> [String: Any] in
      var library: [String: Any] = [
        "LibraryIdentifier": slice.identifier, "LibraryPath": "\(name).framework",
        "SupportedPlatform": slice.platform, "SupportedArchitectures": slice.architectures,
      ]
      library["SupportedPlatformVariant"] = slice.variant
      return library
    }
    try writePlist(["AvailableLibraries": libraries, "XCFrameworkFormatVersion": "1.0"],
                   to: xcframework + "/Info.plist")
    for slice in slices where slice.createsDirectory {
      let framework = "\(xcframework)/\(slice.identifier)/\(name).framework"
      if slice.hasBinary {
        try addFile("\(framework)/\(name)", "!<arch>\n")
      }
      for header in slice.headers {
        try addFile("\(framework)/Headers/\(header)")
      }
      for header in slice.privateHeaders {
        try addFile("\(framework)/PrivateHeaders/\(header)")
      }
      if let moduleMap = slice.moduleMap {
        try addFile("\(framework)/Modules/module.modulemap", moduleMap)
      }
      for bundle in slice.bundles {
        try addFile("\(framework)/\(bundle).bundle/Info.plist")
      }
      try writePlist(["CFBundleShortVersionString": slice.version,
                      "MinimumOSVersion": slice.minimumOS,
                      "CFBundleIdentifier": "com.example.\(name)"],
                     to: framework + "/Info.plist")
    }
    return root + "/" + xcframework
  }

  func read() async throws -> Distribution {
    try await readDistribution(at: root)
  }

  private func writePlist(_ plist: [String: Any], to path: String) throws {
    try addFile(path)
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml,
                                                  options: 0)
    try data.write(to: URL(fileURLWithPath: root + "/" + path))
  }
}

struct DistributionTests {
  @Test func readsRootFilesFoldersFrameworksAndSlices() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("NOTICES", "notices")
    try fake.addFile("Firebase.h")
    try fake.addFile("FirebaseCrashlytics/run")
    try fake.addXCFramework("Core", in: "FirebaseAnalytics", slices: [
      FakeSlice(identifier: "ios-arm64", privateHeaders: ["Private.h"], bundles: ["Core_Privacy"]),
      .simulator,
    ])
    try fake.addXCFramework("Crashlytics", in: "FirebaseCrashlytics")

    let distribution = try await fake.read()
    #expect(distribution.files == ["Firebase.h", "NOTICES"])
    #expect(distribution.folders.map(\.name) == ["FirebaseAnalytics", "FirebaseCrashlytics"])
    #expect(distribution.folders[1].files == ["run"])
    #expect(distribution.folders[1].xcframeworks.map(\.name) == ["Crashlytics"])

    let core = try #require(distribution.xcframeworks.first)
    #expect(core.folder == "FirebaseAnalytics")
    #expect(core.slices.map(\.identifier) == ["ios-arm64", "ios-arm64_x86_64-simulator"])
    #expect(core.signature == Signature(isSigned: false))
    let device = try #require(core.iOSDeviceSlice)
    #expect(device.variant == nil)
    #expect(device.architectures == ["arm64"])
    #expect(device.exists)
    #expect(device.binaryKind == "static")
    #expect(device.headers == ["Core.h"])
    #expect(device.privateHeaders == ["Private.h"])
    #expect(device.modules == ["module.modulemap"])
    #expect(device.moduleMap?.contains("framework module Core") == true)
    #expect(!device.hasSwiftInterface)
    #expect(device.infoPlist["CFBundleShortVersionString"] == "1.0.0")
    #expect(device.resourceBundles == ["Core_Privacy.bundle"])
    #expect(core.slices[1].variant == "simulator")

    #expect(core.qualifiedName == "FirebaseAnalytics/Core")
    #expect(device.isFramework)
    #expect(device.libraryName == "Core")
    #expect(device.libraryDirectory == core.path + "/ios-arm64")
  }

  /// A library slice (not a `.framework`) is named after its file, without the extension.
  @Test func librarySlicesArentFrameworks() {
    let slice = Slice(identifier: "ios-arm64", platform: "ios", architectures: ["arm64"],
                      libraryPath: "/x/Core.xcframework/ios-arm64/libCore.a",
                      binaryPath: "/x/Core.xcframework/ios-arm64/libCore.a", exists: true,
                      binaryKind: "static", headers: [], privateHeaders: [], modules: [],
                      hasSwiftInterface: false, infoPlist: [:], resourceBundles: [])
    #expect(!slice.isFramework)
    #expect(slice.libraryName == "libCore")
    #expect(slice.libraryDirectory == "/x/Core.xcframework/ios-arm64")
  }

  @Test func reportsMissingBinaries() async throws {
    let fake = try FakeDistribution()
    try fake.addXCFramework("Core", in: "A", slices: [FakeSlice(identifier: "ios-arm64",
                                                                hasBinary: false)])
    let slice = try #require(try await fake.read().xcframeworks.first?.slices.first)
    #expect(slice.binaryKind == "missing")
  }

  /// Every lone directory without `.xcframework`s is unwrapped, however deep.
  @Test func unwrapsNestedLoneDirectories() async throws {
    let fake = try FakeDistribution()
    try fake.addXCFramework("Core", in: "Outer/Inner/A")
    let distribution = try await fake.read()
    #expect(distribution.root == fake.root + "/Outer/Inner")
    #expect(distribution.folders.map(\.name) == ["A"])
  }

  @Test func aPathThatIsntADirectoryIsntADistribution() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("file.txt")
    await #expect(throws: ZipBuilderError.self) {
      try await readDistribution(at: fake.root + "/file.txt")
    }
    await #expect(throws: ZipBuilderError.self) {
      try await readDistribution(at: fake.root + "/missing")
    }
  }

  @Test func unpacksAZipAndUnwrapsItsTopLevelDirectory() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("README.md")
    try fake.addXCFramework("Core", in: "FirebaseAnalytics")
    let zip = (fake.root as NSString).deletingLastPathComponent + "/Firebase.zip"
    try await shell("ditto", ["-c", "-k", "--keepParent", fake.root, zip])

    let distribution = try await readDistribution(at: zip)
    defer { distribution.removeExtracted() }
    #expect(distribution.root.hasSuffix("/Firebase"))
    #expect(distribution.files == ["README.md"])
    #expect(distribution.xcframeworks.map(\.name) == ["Core"])
    let extracted = try #require(distribution.extractedDirectory)
    distribution.removeExtracted()
    #expect(!FileManager.default.fileExists(atPath: extracted))
  }

  /// A zip of loose files reads as a distribution with no folders; it isn't an error.
  @Test func aZipOfLooseFilesHasNoFolders() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("notes.txt", "not a distribution")
    let zip = (fake.root as NSString).deletingLastPathComponent + "/notes.zip"
    try await shell("ditto", ["-c", "-k", fake.root, zip]) // the contents, not `Firebase/`

    let distribution = try await readDistribution(at: zip)
    defer { distribution.removeExtracted() }
    #expect(distribution.files == ["notes.txt"])
    #expect(distribution.folders.isEmpty)
    #expect(distribution.extractedDirectory != nil)
  }

  /// A zip `ditto` can't unpack throws, and leaves no `zip-builder-*` directory behind.
  @Test func anUnreadableZipLeavesNothingBehind() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("broken.zip", "not a zip")
    let temporary = FileManager.default.temporaryDirectory.path
    let prefix = "zip-builder-"
    func unpackedZips() -> Set<String> {
      let entries = (try? FileManager.default.contentsOfDirectory(atPath: temporary)) ?? []
      return Set(entries.filter {
        $0.hasPrefix(prefix) && UUID(uuidString: String($0.dropFirst(prefix.count))) != nil
      })
    }
    let before = unpackedZips()

    let error = await #expect(throws: ShellError.self) {
      try await readDistribution(at: fake.root + "/broken.zip")
    }
    // Other tests unpack zips in parallel, so the listings can differ by their directories. This
    // call's directory is the last argument of the `ditto` that failed.
    let directory = try #require(error?.commandLine.split(separator: " ").last.map(String.init))
    #expect(directory.hasPrefix(temporary + "/" + prefix))
    #expect(!unpackedZips().subtracting(before).contains(fileName(directory)))
    #expect(!FileManager.default.fileExists(atPath: directory))
  }

  /// Hidden files, `.DS_Store` and `__MACOSX` are ignored at every level, and a zip's top-level
  /// `__MACOSX` and `.DS_Store` don't stop its `Firebase/` from being unwrapped.
  @Test func hiddenFilesAndMacOSXDirectoriesAreIgnored() async throws {
    let fake = try FakeDistribution()
    try fake.addFile("NOTICES")
    for junk in [".DS_Store", ".hidden", "__MACOSX/junk", "A/.DS_Store", "A/.git/HEAD",
                 "A/__MACOSX/junk",
                 "A/Core.xcframework/ios-arm64/Core.framework/Headers/.DS_Store"] {
      try fake.addFile(junk)
    }
    try fake.addXCFramework("Core", in: "A")

    let distribution = try await fake.read()
    #expect(distribution.files == ["NOTICES"])
    #expect(distribution.folders.map(\.name) == ["A"])
    #expect(distribution.folders.first?.files == [])
    #expect(distribution.xcframeworks.map(\.name) == ["Core"])
    #expect(distribution.xcframeworks.first?.iOSDeviceSlice?.headers == ["Core.h"])

    let parent = (fake.root as NSString).deletingLastPathComponent
    for junk in ["/.DS_Store", "/__MACOSX/Firebase/junk"] {
      try FileManager.default.createDirectory(
        atPath: ((parent + junk) as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true
      )
      try Data().write(to: URL(fileURLWithPath: parent + junk))
    }
    let zip = parent + ".zip"
    defer { try? FileManager.default.removeItem(atPath: zip) }
    try await shell("ditto", ["-c", "-k", parent, zip]) // `Firebase/`, `__MACOSX/`, `.DS_Store`
    let unzipped = try await readDistribution(at: zip)
    defer { unzipped.removeExtracted() }
    #expect(unzipped.root.hasSuffix("/Firebase"))
    #expect(unzipped.files == ["NOTICES"])
    #expect(unzipped.folders.map(\.name) == ["A"])
  }

  @Test func readsAdHocSignatures() async throws {
    let fake = try FakeDistribution()
    let path = try fake.addXCFramework("Core", in: "A")
    try await shell("codesign", ["--force", "--sign", "-", path])
    let xcframework = try #require(try await fake.read().xcframeworks.first)
    #expect(xcframework.signature == Signature(isSigned: true, authority: "ad-hoc"))
  }

  @Test func readsExportedSymbolsOfAStaticLibrary() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("zip-builder-nm-\(UUID().uuidString)").path
    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: directory) }
    try "int exported(void) { return 1; }\nstatic int hidden(void) { return 2; }\n"
      .write(toFile: directory + "/a.c", atomically: true, encoding: .utf8)
    try await shell("xcrun", ["clang", "-c", "a.c", "-o", "a.o"], in: directory)
    try await shell("xcrun", ["libtool", "-static", "-o", "liba.a", "a.o"], in: directory)

    #expect(await exportedSymbols(of: directory + "/liba.a") == ["_exported"])
    #expect(await exportedSymbols(of: directory + "/missing.a") == [])
  }
}
