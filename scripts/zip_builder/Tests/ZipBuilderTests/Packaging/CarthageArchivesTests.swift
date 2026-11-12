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

/// A new temporary directory for one test.
func carthageScratch() throws -> URL {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("zip-builder-tests/carthage/\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  return directory
}

/// Writes `text` to `path` under `root`, creating its directories.
func write(_ text: String, to path: Path, in root: URL) throws {
  let file = root.appendingPathComponent(path)
  try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                          withIntermediateDirectories: true)
  try Data(text.utf8).write(to: file)
}

/// A folder like a macOS-style framework's: files, and links to a directory and to a file.
private func makeFolder(named name: String, in root: URL) throws -> URL {
  let folder = root.appendingPathComponent(name)
  try write("binary", to: "A.xcframework/macos/A.framework/Versions/A/A", in: folder)
  try write("plist", to: "A.xcframework/Info.plist", in: folder)
  let framework = folder.appendingPathComponent("A.xcframework/macos/A.framework")
  try FileManager.default.createSymbolicLink(atPath: framework.path + "/Versions/Current",
                                             withDestinationPath: "A")
  try FileManager.default.createSymbolicLink(atPath: framework.path + "/A",
                                             withDestinationPath: "Versions/Current/A")
  return folder
}

private func carthageConfig(manifests: Path = "Carthage/{folder}Binary.json") -> Config.Carthage {
  Config.Carthage(url: "https://example.com/{version}/{archive}", manifests: manifests)
}

struct CarthageArchivesTests {
  @Test func namesHashOnlyRelativePathsAndContents() throws {
    let first = try carthageScratch()
    let second = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: first) }
    defer { try? FileManager.default.removeItem(at: second) }
    let name = try carthageArchiveName(of: makeFolder(named: "Mini", in: first))
    #expect(name.hasPrefix("Mini-") && name.hasSuffix(".zip"))
    let hash = name.dropFirst("Mini-".count).dropLast(".zip".count)
    #expect(hash.count == 16 && hash.allSatisfy(\.isHexDigit))
    // The same contents somewhere else: the same name.
    #expect(try carthageArchiveName(of: makeFolder(named: "Mini", in: second)) == name)
  }

  @Test func theHashChangesWithEachPathContentsAndLinkTarget() throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = try makeFolder(named: "Mini", in: root)
    var seen = try [folderContentsHash(folder)]
    func expectNewHash() throws {
      let hash = try folderContentsHash(folder)
      #expect(!seen.contains(hash))
      seen.append(hash)
    }
    try write("plist 2", to: "A.xcframework/Info.plist", in: folder)
    try expectNewHash()
    try FileManager.default.moveItem(at: folder.appendingPathComponent("A.xcframework/Info.plist"),
                                     to: folder.appendingPathComponent("A.xcframework/B.plist"))
    try expectNewHash()
    // A link counts by its target, not by what it points at: a copy of the file differs.
    let link = folder.appendingPathComponent("A.xcframework/macos/A.framework/A").path
    try FileManager.default.removeItem(atPath: link)
    try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: "Versions/A/A")
    try expectNewHash()
    try FileManager.default.removeItem(atPath: link)
    try write("binary", to: "A.xcframework/macos/A.framework/A", in: folder)
    try expectNewHash()
  }

  /// An empty folder still gets a name, from the hash of nothing.
  @Test func namesAnEmptyFolder() throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let empty = root.appendingPathComponent("Empty")
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    #expect(try carthageArchiveName(of: empty) == "Empty-\(sha256Hex(Data()).prefix(16)).zip")
  }

  /// Every binary spec the CocoaPods-era builder wrote comes back byte for byte. The two retired
  /// products' hand-written files (no spaces after colons) were never written by it.
  @Test func rewritesTheRepoManifestsUnchanged() throws {
    let directory = repoRoot.appendingPathComponent("ReleaseTooling/CarthageJSON")
    let handWritten: Set = ["FirebaseCrashBinary.json", "FirebaseInvitesBinary.json"]
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      .filter { $0.hasSuffix(".json") && !handWritten.contains($0) }
    #expect(names.count > 20)
    for name in names {
      let data = try Data(contentsOf: directory.appendingPathComponent(name))
      let rewritten = try renderManifest(parseManifest(data, path: name))
      #expect(Data(rewritten.utf8) == data, "\(name)")
    }
  }

  /// A copy of a real binary spec gets exactly one new line, and the repo file isn't changed.
  @Test func addsTheVersionToACopyOfARealManifest() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let real = repoRoot
      .appendingPathComponent("ReleaseTooling/CarthageJSON/FirebaseAuthBinary.json")
    let original = try String(contentsOf: real, encoding: .utf8)
    let package = root.appendingPathComponent("package")
    try write(original, to: "Carthage/FirebaseAuthBinary.json", in: package)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("dist/FirebaseAuth"),
                                            withIntermediateDirectories: true)
    let output = root.appendingPathComponent("out")

    let (archives, warnings) = try await collectingWarnings {
      try await makeCarthageArchives(of: root.appendingPathComponent("dist"), carthageConfig(),
                                     version: "99.0.0", packageRoot: package.path, output: output)
    }
    #expect(warnings.isEmpty)
    let archive = try #require(archives.first.map(fileName))
    let written = try String(contentsOf: output.appendingPathComponent("FirebaseAuthBinary.json"),
                             encoding: .utf8)
    let added = "  \"99.0.0\": \"https://example.com/99.0.0/\(archive)\""
    let (before, after) = (original.split(separator: "\n"), written.split(separator: "\n"))
    #expect(after.count == before.count + 1)
    // Versions sort as strings, so 99.0.0 is last; the line before it gains a comma.
    #expect(Array(after.dropLast(3)) == Array(before.dropLast(2)))
    #expect(after[after.count - 3] == before[before.count - 2] + ",")
    #expect(after[after.count - 2] == Substring(added))
    #expect(try String(contentsOf: package.appendingPathComponent(
      "Carthage/FirebaseAuthBinary.json"
    ), encoding: .utf8) == original)
  }

  @Test func createsAMissingManifestAndReplacesAChangedURL() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("package")
    try write(#"{ "1.0.0": "https://example.com/old.zip", "2.0.0": "https://example.com/x.zip" }"#,
              to: "Carthage/BBinary.json", in: package)
    for folder in ["A", "B"] {
      try write("x", to: "\(folder)/file", in: root.appendingPathComponent("dist"))
    }
    let output = root.appendingPathComponent("out")

    let (archives, warnings) = try await collectingWarnings {
      try await makeCarthageArchives(of: root.appendingPathComponent("dist"), carthageConfig(),
                                     version: "2.0.0", packageRoot: package.path, output: output)
    }
    let names = archives.map(fileName)
    #expect(warnings == [
      "carthage.manifests: Carthage/ABinary.json doesn't exist; it's created with only 2.0.0.",
      "carthage.manifests: Carthage/BBinary.json already lists 2.0.0 as "
        + "https://example.com/x.zip; replaced with https://example.com/2.0.0/\(names[1]).",
    ])
    #expect(try String(contentsOf: output.appendingPathComponent("ABinary.json"), encoding: .utf8)
      == "{\n  \"2.0.0\": \"https://example.com/2.0.0/\(names[0])\"\n}\n")
    #expect(try String(contentsOf: output.appendingPathComponent("BBinary.json"), encoding: .utf8)
      == "{\n  \"1.0.0\": \"https://example.com/old.zip\",\n"
      + "  \"2.0.0\": \"https://example.com/2.0.0/\(names[1])\"\n}\n")
  }

  /// One archive per folder, with the folder at its top and links kept as links; loose files at
  /// the root aren't archived.
  @Test func archivesEachFolderWithItsLinks() async throws {
    let root = try carthageScratch()
    defer { try? FileManager.default.removeItem(at: root) }
    let dist = root.appendingPathComponent("dist")
    let folder = try makeFolder(named: "Mini", in: dist)
    try write("notices", to: "NOTICES", in: dist)
    let output = root.appendingPathComponent("out")

    let (archives, _) = try await collectingWarnings {
      try await makeCarthageArchives(of: dist, carthageConfig(), version: "1.0.0",
                                     packageRoot: root.path, output: output)
    }
    #expect(try archives == [output.appendingPathComponent(carthageArchiveName(of: folder)).path])
    #expect(try FileManager.default.contentsOfDirectory(atPath: output.path).sorted()
      == [fileName(archives[0]), "MiniBinary.json"])
    // `zipinfo`'s first column is the entry's mode: `l` for a link.
    let entries = try await shell("zipinfo", [archives[0]]).split(separator: "\n")
    let links = entries.filter { $0.hasPrefix("l") }.compactMap { $0.split(separator: " ").last }
    #expect(links.sorted() == ["Mini/A.xcframework/macos/A.framework/A",
                               "Mini/A.xcframework/macos/A.framework/Versions/Current"])
    #expect(entries.contains { $0.hasSuffix(" Mini/A.xcframework/Info.plist") })
    #expect(!entries.contains { $0.contains("NOTICES") })
  }
}
